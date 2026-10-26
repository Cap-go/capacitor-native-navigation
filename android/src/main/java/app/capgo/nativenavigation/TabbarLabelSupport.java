package app.capgo.nativenavigation;

import android.graphics.Paint;
import android.graphics.Typeface;

/** Tab label sizing for accessibility font scales (unit tested). */
public final class TabbarLabelSupport {

    static final int TAB_LABEL_MIN_HEIGHT_DP = 18;
    static final int TAB_LABEL_TEXT_SP = 12;

    private TabbarLabelSupport() {}

    /**
     * Line height for a single-line tab label at the current density and font scale.
     * Never smaller than {@link #TAB_LABEL_MIN_HEIGHT_DP} converted to pixels.
     */
    public static int tabLabelHeightPx(float density, float scaledDensity) {
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setTypeface(Typeface.DEFAULT_BOLD);
        paint.setTextSize(TAB_LABEL_TEXT_SP * scaledDensity);
        Paint.FontMetrics metrics = paint.getFontMetrics();
        int lineHeightPx = (int) Math.ceil(metrics.descent - metrics.ascent);
        int minPx = Math.round(TAB_LABEL_MIN_HEIGHT_DP * density);
        return Math.max(minPx, lineHeightPx);
    }

    /** Pixels to add to the configured tab bar height when labels exceed the minimum row height. */
    public static int tabbarExtraHeightPx(int labelHeightPx, int minLabelHeightPx) {
        return Math.max(0, labelHeightPx - minLabelHeightPx);
    }

    /** Content height for the selected-tab indicator (icon + gap + label row). */
    public static int indicatorContentHeightPx(
        int labelHeightPx,
        int iconSizePx,
        int iconLabelGapPx,
        boolean labelVisible,
        boolean iconVisible
    ) {
        int height = 0;
        if (iconVisible) {
            height += iconSizePx;
        }
        if (labelVisible) {
            height += labelHeightPx + (iconVisible ? iconLabelGapPx : 0);
        }
        return height;
    }
}
