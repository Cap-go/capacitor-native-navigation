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
