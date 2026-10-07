package app.capgo.nativenavigation;

import android.graphics.Color;

public final class TabbarChromeSupport {

    private TabbarChromeSupport() {}

    public static int resolveSelectedIndicatorColor(Integer explicitColor, int tintColor) {
        if (explicitColor != null) {
            return explicitColor;
        }
        return Color.argb(34, Color.red(tintColor), Color.green(tintColor), Color.blue(tintColor));
    }

    public static float floatingPillOutlineRadius(float height) {
        return height / 2f;
    }
}
