package app.capgo.nativenavigation;

public final class NavbarScrollSupport {

    public enum ScrollBehavior {
        NONE,
        HIDE_ON_SCROLL_DOWN,
        REVEAL_ON_SCROLL_UP,
        BOTH
    }

    public enum ScrollAction {
        NONE,
        HIDE,
        REVEAL
    }

    private NavbarScrollSupport() {}

    public static ScrollBehavior parseBehavior(String value) {
        if (value == null) {
            return ScrollBehavior.NONE;
        }
        switch (value) {
            case "hideOnScrollDown":
                return ScrollBehavior.HIDE_ON_SCROLL_DOWN;
            case "revealOnScrollUp":
                return ScrollBehavior.REVEAL_ON_SCROLL_UP;
            case "both":
                return ScrollBehavior.BOTH;
            default:
                return ScrollBehavior.NONE;
        }
    }

    public static ScrollAction scrollAction(
        ScrollBehavior behavior,
        float offsetY,
        float deltaY,
        float threshold,
        boolean collapsed
    ) {
        if (behavior == ScrollBehavior.NONE) {
            return ScrollAction.NONE;
        }

        if (offsetY <= threshold && collapsed) {
            return ScrollAction.REVEAL;
        }

        if (deltaY > threshold) {
            if (behavior == ScrollBehavior.HIDE_ON_SCROLL_DOWN || behavior == ScrollBehavior.BOTH) {
                return collapsed ? ScrollAction.NONE : ScrollAction.HIDE;
            }
        } else if (deltaY < -threshold) {
            if (behavior == ScrollBehavior.REVEAL_ON_SCROLL_UP || behavior == ScrollBehavior.BOTH) {
                return collapsed ? ScrollAction.REVEAL : ScrollAction.NONE;
            }
        }

        return ScrollAction.NONE;
    }
}
