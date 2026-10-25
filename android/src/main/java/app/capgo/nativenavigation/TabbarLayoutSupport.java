package app.capgo.nativenavigation;

import android.view.View;

/** Layout helpers for native tab bars (unit tested). */
public final class TabbarLayoutSupport {

    private TabbarLayoutSupport() {}

    public static boolean isRtlLayoutDirection(String layoutDirection) {
        return "rtl".equals(layoutDirection);
    }

    public static int viewLayoutDirectionForTabbarOption(String layoutDirection) {
        if ("rtl".equals(layoutDirection)) {
            return View.LAYOUT_DIRECTION_RTL;
        }
        if ("ltr".equals(layoutDirection)) {
            return View.LAYOUT_DIRECTION_LTR;
        }
        return View.LAYOUT_DIRECTION_INHERIT;
    }

    public static int trailingActionLeft(int width, int trailingDiameter, boolean layoutRtl) {
        return layoutRtl ? 0 : Math.max(0, width - trailingDiameter);
    }

    public static int capsuleLeftForDetachedTrailing(int trailingDiameter, int gap, boolean layoutRtl) {
        return layoutRtl ? trailingDiameter + gap : 0;
    }

    public static final int SIDEBAR_WIDTH_DP = 84;

    /**
     * Absolute left edge of a floating tab bar. `start` and `end` follow the layout direction.
     * `margin` is the inset already used to size the bar.
     */
    public static int floatingBarOriginX(int containerWidth, int barWidth, int margin, String alignment, boolean layoutRtl) {
        int remaining = Math.max(0, containerWidth - barWidth);
        int start = Math.min(Math.max(margin, 0), remaining);
        int end = Math.max(0, remaining - start);
        if ("start".equals(alignment)) {
            return layoutRtl ? end : start;
        }
        if ("end".equals(alignment)) {
            return layoutRtl ? start : end;
        }
        return remaining / 2;
    }

    /** Absolute left edge of a trailing sidebar rail. */
    public static int sidebarOriginX(int containerWidth, int railWidth, int margin, boolean layoutRtl) {
        int remaining = Math.max(0, containerWidth - railWidth - margin);
        return layoutRtl ? margin : remaining;
    }

    public static int[] slotLefts(int rangeLeft, int rangeWidth, int[] childWidths, boolean layoutRtl) {
        int count = childWidths.length;
        int[] lefts = new int[count];
        if (count == 0) {
            return lefts;
        }
        if (!layoutRtl) {
            int cursor = rangeLeft;
            for (int index = 0; index < count; index++) {
                lefts[index] = cursor;
                cursor += childWidths[index];
            }
            return lefts;
        }
        int cursor = rangeLeft + rangeWidth;
        for (int index = 0; index < count; index++) {
            cursor -= childWidths[index];
            lefts[index] = cursor;
        }
        return lefts;
    }

    public static boolean dragRangeContains(float x, float[] centers, float[] widths) {
        if (centers == null || widths == null || centers.length == 0 || centers.length != widths.length) {
            return false;
        }
        float min = centers[0] - widths[0] / 2f;
        float max = centers[0] + widths[0] / 2f;
        for (int index = 1; index < centers.length; index++) {
            min = Math.min(min, centers[index] - widths[index] / 2f);
            max = Math.max(max, centers[index] + widths[index] / 2f);
        }
        return x >= min && x <= max;
    }

    public static float dragPositionAt(float x, float[] centers, boolean layoutRtl) {
        int last = centers == null ? -1 : centers.length - 1;
        if (last < 0) {
            return 0f;
        }
        if (!layoutRtl) {
            if (x <= centers[0]) {
                return 0f;
            }
            if (x >= centers[last]) {
                return last;
            }
            for (int index = 0; index < last; index++) {
                float start = centers[index];
                float end = centers[index + 1];
                if (x < end) {
                    return index + (end > start ? (x - start) / (end - start) : 0f);
                }
            }
            return last;
        }
        if (x >= centers[0]) {
            return 0f;
        }
        if (x <= centers[last]) {
            return last;
        }
        for (int index = 0; index < last; index++) {
            float outer = centers[index];
            float inner = centers[index + 1];
            if (x > inner) {
                return index + (outer > inner ? (outer - x) / (outer - inner) : 0f);
            }
        }
        return last;
    }
}
