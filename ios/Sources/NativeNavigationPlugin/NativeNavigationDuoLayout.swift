import CoreGraphics
import UIKit

/// Physical geometry of a tab bar that UIKit has moved into a vertical rail.
struct NativeNavigationVerticalRail: Equatable {
    var isVertical: Bool
    var onLeft: Bool
    var width: CGFloat
}

/// Shared opt-out. The content view controller reads this when iOS 27.1 asks
/// for `preferredVerticalBarBehavior`. Older systems never ask.
enum NativeNavigationVerticalBarPreference {
    static var disabled = false
}

/// A rail is the short side of the tab bar: taller than it is wide.
func nativeNavigationVerticalRail(tabBarFrame: CGRect, containerWidth: CGFloat) -> NativeNavigationVerticalRail {
    let isVertical = containerWidth > 0 && tabBarFrame.width > 0 && tabBarFrame.height > tabBarFrame.width
    let onLeft = tabBarFrame.midX < containerWidth / 2
    return NativeNavigationVerticalRail(
        isVertical: isVertical,
        onLeft: onLeft,
        width: isVertical ? tabBarFrame.width : 0
    )
}

/// LTR maps physical left to leading. RTL flips that mapping. The rail stays on
/// the camera's physical edge, so the semantic edge changes with layout direction.
func nativeNavigationVerticalBarEdge(railOnLeft: Bool, layoutRtl: Bool) -> String {
    let leading = layoutRtl ? !railOnLeft : railOnLeft
    return leading ? "leading" : "trailing"
}

/// Prefer the system trait. Fall back to the tab bar frame when the trait is
/// unspecified but the bar is already vertical.
func nativeNavigationResolvedVerticalBarEdge(
    traitEdge: String?,
    rail: NativeNavigationVerticalRail,
    layoutRtl: Bool
) -> String? {
    if traitEdge == "leading" || traitEdge == "trailing" {
        return traitEdge
    }
    guard rail.isVertical else {
        return nil
    }
    return nativeNavigationVerticalBarEdge(railOnLeft: rail.onLeft, layoutRtl: layoutRtl)
}

struct NativeNavigationDuoEdgeInsets: Equatable {
    var left: CGFloat
    var right: CGFloat
    var bottom: CGFloat
    var tabbarHeight: CGFloat
    var systemTabbarHeight: CGFloat
}

/// Side insets for a vertical rail. A horizontal bar keeps the caller's insets.
/// When the hosted content is already narrower than the root by about the rail,
/// its own safe area is the source of truth so CSS does not pad a second time.
func nativeNavigationDuoEdgeInsets(
    rootSafe: UIEdgeInsets,
    contentSafe: UIEdgeInsets,
    rootWidth: CGFloat,
    contentWidth: CGFloat,
    rail: NativeNavigationVerticalRail,
    hosted: Bool,
    horizontalTabbarHeight: CGFloat,
    horizontalSystemTabbarHeight: CGFloat
) -> NativeNavigationDuoEdgeInsets {
    guard rail.isVertical else {
        return NativeNavigationDuoEdgeInsets(
            left: rootSafe.left,
            right: rootSafe.right,
            bottom: horizontalTabbarHeight,
            tabbarHeight: horizontalTabbarHeight,
            systemTabbarHeight: horizontalSystemTabbarHeight
        )
    }

    let boundsExcludeRail = hosted && rootWidth > 0 && contentWidth + 1 < rootWidth - (rail.width * 0.5)
    let left: CGFloat
    let right: CGFloat
    if boundsExcludeRail {
        left = contentSafe.left
        right = contentSafe.right
    } else if rail.onLeft {
        left = max(hosted ? contentSafe.left : rootSafe.left, rail.width)
        right = hosted ? contentSafe.right : rootSafe.right
    } else {
        left = hosted ? contentSafe.left : rootSafe.left
        right = max(hosted ? contentSafe.right : rootSafe.right, rail.width)
    }

    let bottom = hosted ? contentSafe.bottom : rootSafe.bottom
    return NativeNavigationDuoEdgeInsets(
        left: left,
        right: right,
        bottom: bottom,
        tabbarHeight: 0,
        systemTabbarHeight: rail.width
    )
}

struct NativeNavigationDockButton: Equatable {
    var id: String
    var dock: String
    var group: String?
}

struct NativeNavigationDockGroup: Equatable {
    var ids: [String]
    /// Two or more items collapse to an actionless copy of the first.
    var expandable: Bool
}

struct NativeNavigationDockPartition: Equatable {
    /// Original order, including prominent items. Used below iOS 16.
    var plainLeft: [String]
    var plainRight: [String]
    var leadingGroups: [NativeNavigationDockGroup]
    var trailingGroups: [NativeNavigationDockGroup]
    /// Prominent items, leading side first, then trailing.
    var pinned: [String]
    var usesLeadingGroups: Bool
    var usesTrailingGroups: Bool
}

func nativeNavigationBarButtonDock(_ raw: String?) -> String {
    switch raw {
    case "detached", "prominent":
        return raw ?? "shared"
    default:
        return "shared"
    }
}

func nativeNavigationBarButtonAxis(_ raw: String?) -> String {
    switch raw {
    case "horizontal", "vertical":
        return raw ?? "automatic"
    default:
        return "automatic"
    }
}

func nativeNavigationDockGroup(_ raw: String?) -> String? {
    guard let raw else {
        return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

func nativeNavigationVerticalBarCompression(_ raw: String?) -> String {
    switch raw {
    case "preferItems", "preferTabs":
        return raw ?? "automatic"
    default:
        return "automatic"
    }
}

func nativeNavigationSearchPlacementIsButton(_ placement: String?) -> Bool {
    placement == "button"
}

/// Explicit `icon` wins. Explicit `title` stays text. An omitted display makes
/// `close` an icon. Any other omitted display is an icon only when the title
/// is empty, so the historical default title `"Back"` stays text.
func nativeNavigationBackButtonIsIcon(display: String?, title: String?, role: String?) -> Bool {
    if display == "icon" {
        return true
    }
    if display == "title" {
        return false
    }
    if role == "close" {
        return true
    }
    return (title ?? "Back").isEmpty
}

func nativeNavigationBackButtonAccessibilityLabel(title: String?, role: String?) -> String {
    if let title, !title.isEmpty {
        return title
    }
    return role == "close" ? "Close" : "Back"
}

func nativeNavigationBarButtonAccessibilityLabel(accessibilityLabel: String?, title: String?, id: String) -> String {
    if let accessibilityLabel, !accessibilityLabel.isEmpty {
        return accessibilityLabel
    }
    if let title, !title.isEmpty {
        return title
    }
    return id
}

func nativeNavigationPartitionDock(
    left: [NativeNavigationDockButton],
    right: [NativeNavigationDockButton]
) -> NativeNavigationDockPartition {
    let pinned = left.filter { $0.dock == "prominent" }.map(\.id) + right.filter { $0.dock == "prominent" }.map(\.id)
    let leading = nativeNavigationPartitionDockSide(left.filter { $0.dock != "prominent" })
    let trailing = nativeNavigationPartitionDockSide(right.filter { $0.dock != "prominent" })
    return NativeNavigationDockPartition(
        plainLeft: left.map(\.id),
        plainRight: right.map(\.id),
        leadingGroups: leading.groups,
        trailingGroups: trailing.groups,
        pinned: pinned,
        usesLeadingGroups: leading.expandable,
        usesTrailingGroups: trailing.expandable
    )
}

private func nativeNavigationPartitionDockSide(
    _ items: [NativeNavigationDockButton]
) -> (groups: [NativeNavigationDockGroup], expandable: Bool) {
    var counts: [String: Int] = [:]
    for item in items where item.dock != "detached" {
        if let group = item.group {
            counts[group, default: 0] += 1
        }
    }

    var emitted: Set<String> = []
    var groups: [NativeNavigationDockGroup] = []
    var expandable = false
    for item in items {
        let groupId = item.dock == "detached" ? nil : item.group
        if let groupId, (counts[groupId] ?? 0) >= 2 {
            if emitted.contains(groupId) {
                continue
            }
            emitted.insert(groupId)
            let ids = items.filter { $0.dock != "detached" && $0.group == groupId }.map(\.id)
            groups.append(NativeNavigationDockGroup(ids: ids, expandable: true))
            expandable = true
        } else {
            groups.append(NativeNavigationDockGroup(ids: [item.id], expandable: false))
        }
    }
    return (groups, expandable)
}

func nativeNavigationTabContentController(from viewController: UIViewController?) -> NativeNavigationTabContentController? {
    if let content = viewController as? NativeNavigationTabContentController {
        return content
    }
    guard let navigation = viewController as? UINavigationController else {
        return nil
    }
    return navigation.viewControllers.first as? NativeNavigationTabContentController
        ?? navigation.topViewController as? NativeNavigationTabContentController
}
