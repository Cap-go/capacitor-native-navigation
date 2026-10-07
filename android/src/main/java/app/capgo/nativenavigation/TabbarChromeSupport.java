package app.capgo.nativenavigation;

public final class TabbarChromeSupport {

    public static final int TABBAR_VISIBILITY_ANIMATION_MS = 200;

    private TabbarChromeSupport() {}

    public static float tabbarSlideDistancePx(int containerHeight, int bottomMargin, int fallbackDistance) {
        return containerHeight > 0 ? containerHeight + bottomMargin : fallbackDistance;
    }
}
