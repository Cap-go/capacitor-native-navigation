import UIKit

/// One choice inside a navbar segment row, parsed from `setNavbar({ segments })`.
struct NativeNavigationSegmentItem: Equatable {
    let id: String
    let title: String?
    let accessibilityLabel: String?
    let enabled: Bool
    /// Identity of the icon descriptor, so rows rebuild only when the icon really changes.
    let iconKey: String
    let image: UIImage?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.accessibilityLabel == rhs.accessibilityLabel
            && lhs.enabled == rhs.enabled && lhs.iconKey == rhs.iconKey
    }
}

/// A row of native segments under the navbar.
struct NativeNavigationSegmentGroup {
    enum Style {
        case segmented
        case scroll
    }

    let id: String
    let items: [NativeNavigationSegmentItem]
    let selectedId: String?
    let style: Style

    /// Rows with the same layout key keep their views, so only the selection animates.
    var layoutKey: [AnyHashable] {
        [id, style == .segmented ? "segmented" : "scroll"] + items.map {
            [$0.id, $0.title ?? "", $0.accessibilityLabel ?? "", $0.enabled, $0.iconKey] as [AnyHashable]
        }
    }

    var selectedIndex: Int? {
        selectedId.flatMap { selected in items.firstIndex { $0.id == selected } }
    }

    /// `auto` picks the equal-width control while every item still has room.
    static func style(from value: String?, itemCount: Int) -> Style {
        switch value {
        case "segmented":
            return .segmented
        case "scroll":
            return .scroll
        default:
            return itemCount <= 4 ? .segmented : .scroll
        }
    }
}

/// Stacks one native control per segment group under the navbar.
final class NativeNavigationSegmentRowsView: UIView {
    static let rowHeight: CGFloat = 44

    var onSelect: ((_ groupId: String, _ id: String, _ index: Int) -> Void)?

    private var rows: [NativeNavigationSegmentRow] = []

    var contentHeight: CGFloat {
        CGFloat(rows.count) * Self.rowHeight
    }

    func apply(groups: [NativeNavigationSegmentGroup], tint: UIColor?, foreground: UIColor?) {
        let reusable = rows.count == groups.count && zip(rows, groups).allSatisfy { $0.layoutKey == $1.layoutKey }
        if !reusable {
            rows.forEach { $0.removeFromSuperview() }
            rows = groups.map { group in
                let row = NativeNavigationSegmentRow(group: group)
                row.onSelect = { [weak self] id, index in
                    self?.onSelect?(group.id, id, index)
                }
                addSubview(row)
                return row
            }
            setNeedsLayout()
        }
        for (row, group) in zip(rows, groups) {
            row.apply(selectedIndex: group.selectedIndex, tint: tint, foreground: foreground, animated: reusable)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, row) in rows.enumerated() {
            row.frame = CGRect(x: 0, y: CGFloat(index) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
        }
    }
}

private final class NativeNavigationSegmentRow: UIView {
    let layoutKey: [AnyHashable]
    var onSelect: ((_ id: String, _ index: Int) -> Void)?

    private let group: NativeNavigationSegmentGroup
    private var segmentedControl: UISegmentedControl?
    private var scrollView: UIScrollView?
    private var buttons: [UIButton] = []
    private var selectedIndex: Int?
    private var tint: UIColor?
    private var foreground: UIColor?

    private static let horizontalInset: CGFloat = 16
    private static let pillSpacing: CGFloat = 8
    private static let pillHeight: CGFloat = 32

    init(group: NativeNavigationSegmentGroup) {
        self.group = group
        self.layoutKey = group.layoutKey
        super.init(frame: .zero)
        switch group.style {
        case .segmented:
            buildSegmentedControl()
        case .scroll:
            buildScrollRow()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(selectedIndex: Int?, tint: UIColor?, foreground: UIColor?, animated: Bool) {
        self.tint = tint
        self.foreground = foreground
        let changed = self.selectedIndex != selectedIndex
        self.selectedIndex = selectedIndex
        if let control = segmentedControl {
            control.selectedSegmentIndex = selectedIndex ?? UISegmentedControl.noSegment
            // Reassigned on every call so dropping `tint` restores the UIKit default.
            control.selectedSegmentTintColor = tint
            if let foreground {
                control.setTitleTextAttributes([.foregroundColor: foreground], for: .normal)
            }
            // Text on the tinted thumb needs contrast, like the selected scroll pills.
            if let selectedForeground = tint != nil ? UIColor.white : foreground {
                control.setTitleTextAttributes([.foregroundColor: selectedForeground], for: .selected)
            }
            return
        }
        updateButtons()
        if changed {
            scrollSelectedIntoView(animated: animated)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let control = segmentedControl {
            let height: CGFloat = 32
            control.frame = CGRect(
                x: Self.horizontalInset + safeAreaInsets.left,
                y: (bounds.height - height) / 2,
                width: max(0, bounds.width - Self.horizontalInset * 2 - safeAreaInsets.left - safeAreaInsets.right),
                height: height
            )
            return
        }
        guard let scrollView else {
            return
        }
        scrollView.frame = bounds
        var originX = Self.horizontalInset + safeAreaInsets.left
        let originY = (bounds.height - Self.pillHeight) / 2
        for button in buttons {
            let width = ceil(button.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: Self.pillHeight)).width)
            button.frame = CGRect(x: originX, y: originY, width: width, height: Self.pillHeight)
            originX += width + Self.pillSpacing
        }
        let contentWidth = buttons.isEmpty ? 0 : originX - Self.pillSpacing + Self.horizontalInset + safeAreaInsets.right
        let previousWidth = scrollView.contentSize.width
        scrollView.contentSize = CGSize(width: contentWidth, height: bounds.height)
        if previousWidth == 0, contentWidth > 0 {
            scrollSelectedIntoView(animated: false)
        }
    }

    private func buildSegmentedControl() {
        let control = UISegmentedControl()
        for (index, item) in group.items.enumerated() {
            // UISegmentedControl shows a title or an image, not both: the title reads better.
            if let title = item.title, !title.isEmpty {
                control.insertSegment(withTitle: title, at: index, animated: false)
            } else {
                // VoiceOver reads an image segment from the image's own label.
                let image = item.image?.copy() as? UIImage
                image?.accessibilityLabel = item.accessibilityLabel
                control.insertSegment(with: image, at: index, animated: false)
            }
            control.setEnabled(item.enabled, forSegmentAt: index)
        }
        control.apportionsSegmentWidthsByContent = false
        control.addTarget(self, action: #selector(handleSegmentChange(_:)), for: .valueChanged)
        addSubview(control)
        segmentedControl = control
    }

    private func buildScrollRow() {
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.scrollsToTop = false
        addSubview(scrollView)
        self.scrollView = scrollView

        buttons = group.items.enumerated().map { index, item in
            let button = UIButton(type: .system)
            button.tag = index
            button.isEnabled = item.enabled
            button.accessibilityLabel = item.accessibilityLabel ?? item.title
            button.addTarget(self, action: #selector(handlePillTap(_:)), for: .touchUpInside)
            scrollView.addSubview(button)
            return button
        }
    }

    private func updateButtons() {
        for (index, button) in buttons.enumerated() {
            let item = group.items[index]
            let selected = index == selectedIndex
            button.configuration = pillConfiguration(item: item, selected: selected)
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
        setNeedsLayout()
    }

    private func pillConfiguration(item: NativeNavigationSegmentItem, selected: Bool) -> UIButton.Configuration {
        var configuration: UIButton.Configuration
        if #available(iOS 26.0, *) {
            configuration = selected ? .prominentGlass() : .glass()
        } else {
            configuration = selected ? .filled() : .gray()
        }
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        configuration.image = item.image.map { $0.resized(toFit: 16) }
        configuration.imagePadding = 6
        let title = item.title ?? ""
        configuration.attributedTitle = title.isEmpty ? nil : AttributedString(
            title,
            attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: selected ? .semibold : .medium)])
        )
        if selected {
            configuration.baseBackgroundColor = tint
            configuration.baseForegroundColor = .white
        } else {
            configuration.baseForegroundColor = foreground ?? .label
        }
        return configuration
    }

    private func scrollSelectedIntoView(animated: Bool) {
        guard let scrollView, let index = selectedIndex, buttons.indices.contains(index) else {
            return
        }
        layoutIfNeeded()
        let target = buttons[index].frame.insetBy(dx: -Self.horizontalInset, dy: 0)
        scrollView.scrollRectToVisible(target, animated: animated)
    }

    @objc private func handleSegmentChange(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard group.items.indices.contains(index) else {
            return
        }
        selectedIndex = index
        onSelect?(group.items[index].id, index)
    }

    @objc private func handlePillTap(_ sender: UIButton) {
        let index = sender.tag
        guard group.items.indices.contains(index) else {
            return
        }
        if selectedIndex != index {
            selectedIndex = index
            updateButtons()
            scrollSelectedIntoView(animated: true)
        }
        onSelect?(group.items[index].id, index)
    }
}

private extension UIImage {
    /// Pill icons follow the label size; SVG icons render at 24pt by default.
    func resized(toFit side: CGFloat) -> UIImage {
        guard size.width > side || size.height > side, size.width > 0, size.height > 0 else {
            return self
        }
        if isSymbolImage {
            return withConfiguration(UIImage.SymbolConfiguration(pointSize: side * 0.9, weight: .medium))
        }
        let scale = side / max(size.width, size.height)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let image = UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return image.withRenderingMode(renderingMode)
    }
}
