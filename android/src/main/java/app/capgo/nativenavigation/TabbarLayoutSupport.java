package app.capgo.nativenavigation;

/** Layout helpers for native tab bars (unit tested). */
public final class TabbarLayoutSupport {

    private TabbarLayoutSupport() {}

    public static boolean isRtlLayoutDirection(String layoutDirection) {
        return "rtl".equals(layoutDirection);
    }

    public static int trailingActionLeft(int width, int trailingDiameter, boolean layoutRtl) {
        return layoutRtl ? 0 : Math.max(0, width - trailingDiameter);
    }

    public static int capsuleLeftForDetachedTrailing(int trailingDiameter, int gap, boolean layoutRtl) {
        return layoutRtl ? trailingDiameter + gap : 0;
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
}
