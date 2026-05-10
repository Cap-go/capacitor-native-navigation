// swiftlint:disable file_length

import Foundation
import Capacitor
import UIKit
import ObjectiveC

// swiftlint:disable type_body_length
@objc(NativeNavigationPlugin)
public class NativeNavigationPlugin: CAPPlugin, CAPBridgedPlugin {
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
    private var tabBar: NativeNavigationFloatingTabBar?
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
    private var transitionSnapshot: UIView?
    private var activeTransitionId: String?
    private var activeTransitionDirection = "forward"

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
                self.tabContainer?.isHidden = true
                self.tabBar?.isHidden = true
                self.updateInsetsAndNotify()
                call.resolve(self.insetsResult())
                return
            }

            let tabBar = self.ensureTabBar()
            let tabs = call.getArray("tabs") as? [[String: Any]] ?? []
            let selectedId = call.getString("selectedId")
            let labels = call.getBool("labels", true)
            let icons = call.getBool("icons", true)

            let (items, selectedIndex) = self.makeFloatingTabItems(
                tabs,
                selectedId: selectedId,
                labels: labels,
                icons: icons
            )

            self.applyTabBarAppearance(tabBar: tabBar, options: call)
            let resolvedSelectedIndex = selectedIndex ?? (items.indices.contains(tabBar.selectedIndex) ? tabBar.selectedIndex : 0)
            tabBar.configure(
                items: items,
                selectedIndex: resolvedSelectedIndex,
                labels: labels,
                icons: icons
            )
            tabBar.onSelect = { [weak self] index, item in
                self?.notifyListeners("tabSelect", data: [
                    "id": item.id,
                    "index": index,
                    "title": item.title
                ])
            }
            self.tabContainer?.isHidden = false
            tabBar.isHidden = false
            self.layoutChrome()
            self.updateInsetsAndNotify()
            call.resolve(self.insetsResult())
        }
    }

    @objc func beginTransition(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            guard let webView = self.webView, let rootView = self.bridge?.viewController?.view else {
                call.reject("WebView unavailable")
                return
            }

            let transitionId = call.getString("id") ?? "transition-\(Int(Date().timeIntervalSince1970 * 1_000))"
            let direction = call.getString("direction") ?? "forward"
            let durationMs = Int((call.getDouble("duration") ?? self.defaultTransitionDuration * 1_000).rounded())

            self.transitionSnapshot?.removeFromSuperview()
            let snapshot = webView.snapshotView(afterScreenUpdates: false) ?? UIView(frame: webView.frame)
            snapshot.frame = webView.frame
            snapshot.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            rootView.insertSubview(snapshot, aboveSubview: webView)
            self.bringChromeToFront()
            self.transitionSnapshot = snapshot
            self.activeTransitionId = transitionId
            self.activeTransitionDirection = direction
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
            let width = webView.bounds.width
            let snapshot = self.transitionSnapshot

            let startTransform: CGAffineTransform
            let endSnapshotTransform: CGAffineTransform
            switch direction {
            case "back":
                startTransform = CGAffineTransform(translationX: -width * 0.3, y: 0)
                endSnapshotTransform = CGAffineTransform(translationX: width, y: 0)
            case "tab", "root", "none":
                startTransform = .identity
                endSnapshotTransform = .identity
            default:
                startTransform = CGAffineTransform(translationX: width, y: 0)
                endSnapshotTransform = CGAffineTransform(translationX: -width * 0.3, y: 0)
            }

            webView.transform = startTransform
            webView.alpha = direction == "none" ? 1 : 0.01

            UIView.animate(
                withDuration: max(duration, 0),
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    webView.transform = .identity
                    webView.alpha = 1
                    snapshot?.transform = endSnapshotTransform
                    snapshot?.alpha = direction == "none" ? 0 : 0.75
                },
                completion: { _ in
                    snapshot?.removeFromSuperview()
                    webView.transform = .identity
                    webView.alpha = 1
                    self.transitionSnapshot = nil
                    self.activeTransitionId = nil
                    let event: [String: Any] = ["id": transitionId, "direction": direction, "duration": durationMs]
                    self.notifyListeners("transitionEnd", data: event)
                    call.resolve(event)
                }
            )
        }
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

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.isUserInteractionEnabled = false
        container.addSubview(blurView)

        let bar = NativeNavigationBar()
        bar.hitSlop = UIEdgeInsets(top: 0, left: 0, bottom: 32, right: 0)
        bar.isTranslucent = true
        bar.backgroundColor = .clear
        bar.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        container.addSubview(bar)

        bridge?.viewController?.view.addSubview(container)
        self.navContainer = container
        self.navBlurView = blurView
        self.navBar = bar
        return bar
    }

    private func ensureTabBar() -> NativeNavigationFloatingTabBar {
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

        let bar = NativeNavigationFloatingTabBar()
        bar.backgroundColor = .clear
        bar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        bar.clipsToBounds = true
        container.addSubview(bar)
        bridge?.viewController?.view.addSubview(container)
        self.tabContainer = container
        self.tabEffectView = effectView
        self.tabBar = bar
        return bar
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

    private func makeFloatingTabItems(
        _ tabs: [[String: Any]],
        selectedId: String?,
        labels: Bool,
        icons: Bool
    ) -> ([NativeNavigationFloatingTabItem], Int?) {
        tabIds = []
        tabTitles = []
        var selectedIndex: Int?

        let items = tabs.enumerated().map { index, tab -> NativeNavigationFloatingTabItem in
            let id = tab["id"] as? String ?? "tab-\(index)"
            let title = tab["title"] as? String ?? ""
            let image = icons ? self.image(from: tab["icon"] as? [String: Any]) : nil
            let selectedImage = icons ? self.image(from: tab["selectedIcon"] as? [String: Any]) : nil
            let badge = tab["badge"].map { String(describing: $0) }
            let enabled = tab["enabled"] as? Bool ?? true
            tabIds.append(id)
            tabTitles.append(title)
            if id == selectedId {
                selectedIndex = index
            }
            return NativeNavigationFloatingTabItem(
                id: id,
                title: labels ? title : "",
                accessibilityTitle: title,
                image: image,
                selectedImage: selectedImage,
                badge: badge,
                enabled: enabled
            )
        }

        return (items, selectedIndex)
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

    private func applyNavBarAppearance(navBar: UINavigationBar, options call: CAPPluginCall) {
        let appearance = UINavigationBarAppearance()
        let transparent = call.getBool("transparent", false)
        let backgroundTint = colorOption(call, key: "background")
        let glassEffect = systemGlassEffect(tintColor: backgroundTint)
        if let glassEffect = glassEffect {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.backgroundEffect = nil
            appearance.shadowColor = .clear
            navBlurView?.effect = glassEffect
            navBlurView?.isHidden = false
        } else if transparent {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = .clear
            appearance.shadowColor = .clear
            navBlurView?.effect = UIBlurEffect(style: .systemChromeMaterial)
            navBlurView?.isHidden = false
        } else {
            appearance.configureWithDefaultBackground()
            navBlurView?.isHidden = true
        }

        if let colors = call.getObject("colors") {
            if let tint = colors["tint"] as? String, let color = UIColor(hexString: tint) {
                navBar.tintColor = color
            }
            if let background = colors["background"] as? String,
               let color = UIColor(hexString: background),
               backgroundTint == nil || glassEffect == nil,
               !transparent {
                appearance.backgroundColor = color
            }
        }

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
    }

    private func applyTabBarAppearance(tabBar: NativeNavigationFloatingTabBar, options call: CAPPluginCall) {
        let backgroundTint = colorOption(call, key: "background")
        let glassEffect = systemGlassEffect(tintColor: backgroundTint)
        if let glassEffect = glassEffect {
            tabEffectView?.effect = glassEffect
            tabEffectView?.isHidden = false
            tabEffectView?.contentView.backgroundColor = backgroundTint?.withAlphaComponent(0.12)
        } else {
            tabEffectView?.effect = UIBlurEffect(style: .systemChromeMaterial)
            tabEffectView?.isHidden = false
            tabEffectView?.contentView.backgroundColor = (backgroundTint ?? .systemBackground).withAlphaComponent(0.46)
        }

        if let colors = call.getObject("colors") {
            if let tint = colors["tint"] as? String, let color = UIColor(hexString: tint) {
                tabBar.selectedTintColor = color
            }
            if let inactiveTint = colors["inactiveTint"] as? String, let color = UIColor(hexString: inactiveTint) {
                tabBar.inactiveTintColor = color
            }
        }
        tabBar.setNeedsLayout()
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

        bringChromeToFront()
    }

    private func bringChromeToFront() {
        if let navContainer = navContainer {
            bridge?.viewController?.view.bringSubviewToFront(navContainer)
        }
        if let tabContainer = tabContainer {
            bridge?.viewController?.view.bringSubviewToFront(tabContainer)
        }
    }

    private func colorOption(_ call: CAPPluginCall, key: String) -> UIColor? {
        guard let colors = call.getObject("colors"),
              let value = colors[key] as? String else {
            return nil
        }
        return UIColor(hexString: value)
    }

    private func systemGlassEffect(tintColor: UIColor?) -> UIVisualEffect? {
        guard #available(iOS 26.0, *),
              let glassClass = NSClassFromString("UIGlassEffect"),
              let method = class_getClassMethod(glassClass, NSSelectorFromString("effectWithStyle:")) else {
            return nil
        }

        typealias EffectWithStyle = @convention(c) (AnyClass, Selector, Int) -> Unmanaged<UIVisualEffect>
        let implementation = method_getImplementation(method)
        let makeEffect = unsafeBitCast(implementation, to: EffectWithStyle.self)
        let effect = makeEffect(glassClass, NSSelectorFromString("effectWithStyle:"), 0).takeUnretainedValue()
        let object = effect as NSObject
        if object.responds(to: NSSelectorFromString("setInteractive:")) {
            object.setValue(true, forKey: "interactive")
        }
        if let tintColor = tintColor,
           object.responds(to: NSSelectorFromString("setTintColor:")) {
            object.setValue(tintColor, forKey: "tintColor")
        }
        return effect
    }

    private func configureGlassBarButtonItem(_ item: UIBarButtonItem, id: String) {
        guard #available(iOS 26.0, *) else {
            return
        }
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
        let navHeight = navbarVisible ? navbarHeight + safeInsets.top : 0
        let tabHeight = tabbarVisible ? tabbarHeight + safeInsets.bottom + floatingTabbarBottomGap : 0
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

private struct NativeNavigationFloatingTabItem {
    let id: String
    let title: String
    let accessibilityTitle: String
    let image: UIImage?
    let selectedImage: UIImage?
    let badge: String?
    let enabled: Bool
}

private struct NativeNavigationFloatingTabStyle {
    let selected: Bool
    let labels: Bool
    let icons: Bool
    let selectedTint: UIColor
    let inactiveTint: UIColor
}

private final class NativeNavigationFloatingTabBar: UIView {
    private var items: [NativeNavigationFloatingTabItem] = []
    private var buttons: [NativeNavigationFloatingTabButton] = []
    private var labelsVisible = true
    private var iconsVisible = true

    var selectedIndex = 0
    var selectedTintColor = UIColor.systemBlue {
        didSet { updateButtons() }
    }
    var inactiveTintColor = UIColor.secondaryLabel {
        didSet { updateButtons() }
    }
    var onSelect: ((Int, NativeNavigationFloatingTabItem) -> Void)?

    func configure(
        items: [NativeNavigationFloatingTabItem],
        selectedIndex: Int,
        labels: Bool,
        icons: Bool
    ) {
        self.items = items
        self.labelsVisible = labels
        self.iconsVisible = icons
        self.selectedIndex = items.indices.contains(selectedIndex) ? selectedIndex : 0
        rebuildButtons()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !buttons.isEmpty else {
            return
        }
        let itemWidth = bounds.width / CGFloat(buttons.count)
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(
                x: CGFloat(index) * itemWidth,
                y: 0,
                width: itemWidth,
                height: bounds.height
            )
        }
    }

    private func rebuildButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = items.enumerated().map { index, item in
            let button = NativeNavigationFloatingTabButton()
            button.tag = index
            button.configure(
                item: item,
                style: style(selected: index == selectedIndex)
            )
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
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
                style: style(selected: index == selectedIndex)
            )
        }
    }

    private func style(selected: Bool) -> NativeNavigationFloatingTabStyle {
        return NativeNavigationFloatingTabStyle(
            selected: selected,
            labels: labelsVisible,
            icons: iconsVisible,
            selectedTint: selectedTintColor,
            inactiveTint: inactiveTintColor
        )
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

private final class NativeNavigationFloatingTabButton: UIControl {
    private let selectedView = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()
    private var hasIcon = true
    private var hasLabel = true
    private var badgeText: String?

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
        hasIcon = style.icons && (item.image != nil || item.selectedImage != nil)
        hasLabel = style.labels && !item.title.isEmpty
        badgeText = item.badge

        let color = style.selected ? style.selectedTint : style.inactiveTint
        selectedView.backgroundColor = style.selectedTint.withAlphaComponent(style.selected ? 0.16 : 0)
        selectedView.alpha = style.selected ? 1 : 0

        let image = style.selected ? (item.selectedImage ?? item.image) : item.image
        imageView.image = image
        imageView.tintColor = color
        imageView.isHidden = !hasIcon

        titleLabel.text = item.title
        titleLabel.textColor = color
        titleLabel.font = .systemFont(ofSize: 11, weight: style.selected ? .bold : .semibold)
        titleLabel.isHidden = !hasLabel

        badgeLabel.text = item.badge
        badgeLabel.isHidden = item.badge == nil || item.badge == "0"
        accessibilityLabel = item.accessibilityTitle
        accessibilityTraits = style.selected ? [.button, .selected] : .button
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectedView.frame = bounds.insetBy(dx: 7, dy: 7)
        selectedView.layer.cornerRadius = selectedView.bounds.height / 2

        let iconSize: CGFloat = 23
        if hasIcon && hasLabel {
            imageView.frame = CGRect(x: (bounds.width - iconSize) / 2, y: 10, width: iconSize, height: iconSize)
            titleLabel.frame = CGRect(x: 5, y: bounds.height - 23, width: bounds.width - 10, height: 15)
        } else if hasIcon {
            imageView.frame = CGRect(x: (bounds.width - iconSize) / 2, y: (bounds.height - iconSize) / 2, width: iconSize, height: iconSize)
            titleLabel.frame = .zero
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
