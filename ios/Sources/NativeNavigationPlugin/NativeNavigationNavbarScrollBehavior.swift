import Foundation

enum NativeNavigationNavbarScrollBehavior: String {
    case none
    case hideOnScrollDown
    case revealOnScrollUp
    case both
}

enum NativeNavigationNavbarScrollAction {
    case none
    case hide
    case reveal
}

func nativeNavigationNavbarScrollBehavior(from raw: String?) -> NativeNavigationNavbarScrollBehavior {
    guard let raw = raw, let value = NativeNavigationNavbarScrollBehavior(rawValue: raw) else {
        return .none
    }
    return value
}

func nativeNavigationNavbarScrollAction(
    behavior: NativeNavigationNavbarScrollBehavior,
    offsetY: CGFloat,
    deltaY: CGFloat,
    threshold: CGFloat,
    isCollapsed: Bool
) -> NativeNavigationNavbarScrollAction {
    guard behavior != .none else {
        return .none
    }

    let atTop = offsetY <= threshold
    if atTop && isCollapsed {
        return .reveal
    }

    if deltaY > threshold {
        switch behavior {
        case .hideOnScrollDown, .both:
            return isCollapsed ? .none : .hide
        case .none, .revealOnScrollUp:
            return .none
        }
    } else if deltaY < -threshold {
        switch behavior {
        case .revealOnScrollUp, .both:
            return isCollapsed ? .reveal : .none
        case .none, .hideOnScrollDown:
            return .none
        }
    }

    return .none
}
