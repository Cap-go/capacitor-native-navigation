package app.capgo.nativenavigation;

import android.graphics.Paint;
import android.graphics.Typeface;
import android.os.Build;

/** Tab label sizing for accessibility font scales (unit tested). */
public final class TabbarLabelSupport {

    static final int TAB_LABEL_MIN_HEIGHT_DP = 18;
    static final int TAB_LABEL_TEXT_SP = 12;
    static final int TAB_CONTENT_PADDING_DP = 4;
    static final int TAB_ICON_SIZE_DP = 24;
    static final int TAB_ICON_LABEL_GAP_DP = 2;

    private TabbarLabelSupport() {}

    /**
     * Line height for a single-line tab label at the current density and font scale.
     * Never smaller than {@link #TAB_LABEL_MIN_HEIGHT_DP} converted to pixels.
     */
    public static int tabLabelHeightPx(float density, float scaledDensity) {
        return tabLabelHeightPxForTitle(null, density, scaledDensity, true);
    }

    /**
     * Line height for a displayed title, including fallback glyphs that exceed the main typeface metrics.
     * Uses bold weight to match selected-tab slot sizing in the tab bar.
     */
    public static int tabLabelHeightPxForTitle(String title, float density, float scaledDensity, boolean bold) {
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, bold ? Typeface.BOLD : Typeface.NORMAL));
        paint.setTextSize(TAB_LABEL_TEXT_SP * scaledDensity);
        Paint.FontMetricsInt metrics = new Paint.FontMetricsInt();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && title != null && !title.isEmpty()) {
            paint.getFontMetricsInt(title, 0, title.length(), 0, title.length(), false, metrics);
        } else {
            paint.getFontMetricsInt(metrics);
        }
        int lineHeightPx = metrics.bottom - metrics.top;
        int minPx = Math.round(TAB_LABEL_MIN_HEIGHT_DP * density);
        return Math.max(minPx, lineHeightPx);
    }

    /** Maximum label row height across tab titles (empty list uses generic metrics). */
    public static int maxTabLabelHeightPx(String[] titles, float density, float scaledDensity) {
        int max = tabLabelHeightPx(density, scaledDensity);
        if (titles == null) {
            return max;
        }
        for (String title : titles) {
            if (title == null || title.isEmpty()) {
                continue;
            }
            max = Math.max(max, tabLabelHeightPxForTitle(title, density, scaledDensity, true));
        }
        return max;
    }

    /** Vertical space needed inside a tab slot for icon, gap, label, and content padding. */
    public static int tabSlotContentHeightPx(
        int contentPaddingPx,
        int iconSizePx,
        int iconLabelGapPx,
        int labelHeightPx,
        boolean labelVisible,
        boolean iconVisible
    ) {
        int height = contentPaddingPx * 2;
        if (iconVisible) {
            height += iconSizePx;
        }
        if (labelVisible) {
            height += labelHeightPx;
            if (iconVisible) {
                height += iconLabelGapPx;
            }
        }
        return height;
    }

    /** Pixels to add to the configured tab bar height so slot content fits without clipping. */
    public static int tabbarExtraHeightForContentPx(int configuredBarHeightPx, int requiredSlotContentHeightPx) {
        return Math.max(0, requiredSlotContentHeightPx - configuredBarHeightPx);
    }

    /** Use {@link #tabbarExtraHeightForContentPx} for bar sizing; label-only delta kept for regression tests. */
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
