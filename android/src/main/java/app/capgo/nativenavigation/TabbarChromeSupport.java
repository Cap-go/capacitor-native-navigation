package app.capgo.nativenavigation;

import android.graphics.Path;
import android.graphics.RectF;
import android.os.Build;

public final class TabbarChromeSupport {

    public static final int TABBAR_VISIBILITY_ANIMATION_MS = 200;
    public static final int EDGE_BLUR_BLEED_CSS_PX = 48;

    public enum TabbarOutlineMode {
        FLOATING_SHAPE,
        CURVE_DEFAULT
    }

    private TabbarChromeSupport() {}

    public static float tabbarSlideDistancePx(int containerHeight, int bottomMargin, int fallbackDistance) {
        if (containerHeight > 0) {
            return (float) containerHeight + (float) bottomMargin;
        }
        return (float) fallbackDistance;
    }

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

    /**
     * Adds, resizes or removes the page element that blurs content behind the tabbar. Stacked layers with growing
     * masks make the blur strongest at the bottom edge and fade it out above the bar. A height of 0 removes it.
     */
    public static String edgeBlurScript(int heightCssPx) {
        return (
            "(function(height){" +
            "var id='cap-native-navigation-edge-blur';" +
            "var root=document.getElementById(id);" +
            "if(!(height>0)){if(root){root.remove();}return;}" +
            "if(!root){" +
            "root=document.createElement('div');root.id=id;root.setAttribute('aria-hidden','true');" +
            "root.style.cssText='position:fixed;left:0;right:0;bottom:0;pointer-events:none;z-index:2147483646;';" +
            "[100,84,68,52,36,20].forEach(function(h){" +
            "var layer=document.createElement('div');" +
            "var mask='linear-gradient(to top,#000 0%,#000 '+Math.round(h*0.6)+'%,transparent '+h+'%)';" +
            "layer.style.cssText='position:absolute;left:0;right:0;top:0;bottom:0;-webkit-backdrop-filter:blur(2px);backdrop-filter:blur(2px);-webkit-mask-image:'+mask+';mask-image:'+mask+';';" +
            "root.appendChild(layer);" +
            "});" +
            "}" +
            "if(root.parentNode!==document.body&&document.body){document.body.appendChild(root);}" +
            "root.style.height=height+'px';" +
            "})(" +
            Math.max(0, heightCssPx) +
            ");"
        );
    }

    public static boolean canApplyPathOutline() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.R;
    }
}
