import CoreGraphics
import Foundation

let nativeNavigationNavbarSearchRowPoints: CGFloat = 52

func nativeNavigationNavbarSearchRowHeight(
    visible: Bool,
    hidesWhenCollapsed: Bool,
    largeCollapsed: Bool
) -> CGFloat {
    if !visible || (hidesWhenCollapsed && largeCollapsed) {
        return 0
    }
    return nativeNavigationNavbarSearchRowPoints
}

/// Curve bars stay on the bottom. Unknown values follow the system (`auto`).
func nativeNavigationResolvedTabbarPlacement(raw: String?, shapeIsCurve: Bool) -> String {
    if shapeIsCurve {
        return "bottom"
    }
    switch raw?.lowercased() {
    case "sidebar", "bottom":
        return raw!.lowercased()
    default:
        return "auto"
    }
}

func nativeNavigationResolvedTabbarAlignment(raw: String?) -> String {
    switch raw?.lowercased() {
    case "start", "end":
        return raw!.lowercased()
    default:
        return "center"
    }
}

/// Horizontal origin of a floating tab bar. `start` and `end` follow the layout direction.
func nativeNavigationFloatingBarOriginX(
    containerWidth: CGFloat,
    barWidth: CGFloat,
    margin: CGFloat,
    alignment: String,
    layoutRtl: Bool
) -> CGFloat {
    let remaining = max(0, containerWidth - barWidth)
    let start = min(max(margin, 0), remaining)
    let end = max(0, remaining - start)
    switch alignment {
    case "start":
        return layoutRtl ? end : start
    case "end":
        return layoutRtl ? start : end
    default:
        return remaining / 2
    }
}

func nativeNavigationSidebarOriginX(
    containerWidth: CGFloat,
    railWidth: CGFloat,
    margin: CGFloat,
    layoutRtl: Bool
) -> CGFloat {
    let remaining = max(0, containerWidth - railWidth - margin)
    return layoutRtl ? margin : remaining
}
