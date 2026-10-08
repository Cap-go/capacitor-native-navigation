package app.capgo.nativenavigation;

import android.graphics.Path;
import android.graphics.RectF;
import android.os.Build;

public final class TabbarChromeSupport {

    public enum TabbarOutlineMode {
        FLOATING_SHAPE,
        CURVE_DEFAULT
    }

    private TabbarChromeSupport() {}

    public static int resolveSelectedIndicatorColor(Integer explicitColor, int tintColor) {
        if (explicitColor != null) {
            return explicitColor;
        }
        return (34 << 24) | (tintColor & 0x00FFFFFF);
    }

    public static TabbarOutlineMode outlineModeForShape(String shape) {
        return "curve".equals(shape) ? TabbarOutlineMode.CURVE_DEFAULT : TabbarOutlineMode.FLOATING_SHAPE;
    }

    public static boolean shouldClipGlassToOutline(TabbarOutlineMode mode) {
        return mode == TabbarOutlineMode.FLOATING_SHAPE;
    }

    public static boolean shouldEnableDefaultLiquidGlass(boolean apiAtLeastS, boolean isCurve, boolean glassSpecified) {
        return !glassSpecified && !isCurve && apiAtLeastS;
    }

    public static int floatingCapsuleWidth(int totalWidth, int barHeightPx, int trailingGapPx, boolean hasDetachedTrailing) {
        if (!hasDetachedTrailing) {
            return totalWidth;
        }
        return Math.max(0, totalWidth - barHeightPx - trailingGapPx);
    }

    public static Path buildFloatingTabbarPath(
        int width,
        int height,
        float cornerRadiusPx,
        float barHeightPx,
        float trailingGapPx,
        boolean hasDetachedTrailing
    ) {
        Path path = new Path();
        int capsuleWidth = floatingCapsuleWidth(width, (int) barHeightPx, (int) trailingGapPx, hasDetachedTrailing);
        path.addRoundRect(new RectF(0, 0, capsuleWidth, height), cornerRadiusPx, cornerRadiusPx, Path.Direction.CW);
        if (hasDetachedTrailing) {
            float diameter = barHeightPx;
            float left = width - diameter;
            float top = (height - diameter) / 2f;
            path.addRoundRect(
                new RectF(left, top, left + diameter, top + diameter),
                diameter / 2f,
                diameter / 2f,
                Path.Direction.CW
            );
        }
        return path;
    }

    public static boolean canApplyPathOutline() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.R;
    }
}
