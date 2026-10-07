package app.capgo.nativenavigation;

public final class TabbarChromeSupport {

    private TabbarChromeSupport() {}

    public static int resolveSelectedIndicatorColor(Integer explicitColor, int tintColor) {
        if (explicitColor != null) {
            return explicitColor;
        }
        return (34 << 24) | (tintColor & 0x00FFFFFF);
    }

    public static float floatingPillOutlineRadius(float height) {
        return height / 2f;
    }
}
