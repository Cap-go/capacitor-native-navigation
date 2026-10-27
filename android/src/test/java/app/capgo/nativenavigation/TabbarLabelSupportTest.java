package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertTrue;

import android.content.res.Configuration;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.os.Build;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35, qualifiers = "xxhdpi")
public class TabbarLabelSupportTest {

    private static final int DENSITY_3X_MIN_LABEL_PX = 54;
    private static final float FONT_SCALE = 2f;

    @Test
    public void tabbarExtraHeightForContentZeroWhenBarFitsSlot() {
        int barPx = 200;
        int requiredPx = 180;
        assertEquals(0, TabbarLabelSupport.tabbarExtraHeightForContentPx(barPx, requiredPx));
    }

    @Test
    public void tabbarExtraHeightForContentMatchesShortfall() {
        int configuredBarPx = dp(44);
        int labelPx = dp(30);
        int requiredPx = TabbarLabelSupport.tabSlotContentHeightPx(
            dp(TabbarLabelSupport.TAB_CONTENT_PADDING_DP),
            dp(TabbarLabelSupport.TAB_ICON_SIZE_DP),
            dp(TabbarLabelSupport.TAB_ICON_LABEL_GAP_DP),
            labelPx,
            true,
            true
        );
        assertTrue(requiredPx > configuredBarPx);
        assertEquals(requiredPx - configuredBarPx, TabbarLabelSupport.tabbarExtraHeightForContentPx(configuredBarPx, requiredPx));
    }

    @Test
    public void tabSlotContentHeightIncludesIconGapLabelAndPadding() {
        int paddingPx = 12;
        int iconPx = 72;
        int gapPx = 6;
        int labelPx = 80;
        assertEquals(
            paddingPx * 2 + iconPx + gapPx + labelPx,
            TabbarLabelSupport.tabSlotContentHeightPx(paddingPx, iconPx, gapPx, labelPx, true, true)
        );
    }

    @Test
    public void tabbarExtraHeightLegacyLabelGrowth() {
        assertEquals(0, TabbarLabelSupport.tabbarExtraHeightPx(DENSITY_3X_MIN_LABEL_PX, DENSITY_3X_MIN_LABEL_PX));
        int labelPx = 72;
        assertEquals(labelPx - DENSITY_3X_MIN_LABEL_PX, TabbarLabelSupport.tabbarExtraHeightPx(labelPx, DENSITY_3X_MIN_LABEL_PX));
    }

    @Test
    public void indicatorContentHeightUsesLabelRowHeight() {
        int labelPx = 72;
        int iconPx = 72;
        int gapPx = 6;
        assertEquals(
            iconPx + gapPx + labelPx,
            TabbarLabelSupport.indicatorContentHeightPx(labelPx, iconPx, gapPx, true, true)
        );
    }

    @Test
    public void indicatorContentHeightIconOnlyOmitsLabelRow() {
        int labelPx = 72;
        int iconPx = 72;
        assertEquals(iconPx, TabbarLabelSupport.indicatorContentHeightPx(labelPx, iconPx, 6, false, true));
    }

    @Test
    public void indicatorContentHeightLabelOnlyOmitsIconAndGap() {
        int labelPx = 72;
        assertEquals(labelPx, TabbarLabelSupport.indicatorContentHeightPx(labelPx, 72, 6, true, false));
    }

    @Test
    public void tabLabelHeightPxForTitleIsTitleSensitiveAtLargeFontScale() {
        applyFontScale(FONT_SCALE);
        float density = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().density;
        float scaledDensity = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().scaledDensity;
        int minPx = Math.round(TabbarLabelSupport.TAB_LABEL_MIN_HEIGHT_DP * density);
        String latinTitle = "Home";
        String burmeseTitle = "ကြိုဆိုပါသည်";
        int latinPx = TabbarLabelSupport.tabLabelHeightPxForTitle(latinTitle, density, scaledDensity, true);
        int burmesePx = TabbarLabelSupport.tabLabelHeightPxForTitle(burmeseTitle, density, scaledDensity, true);
        assertEquals(expectedTabLabelHeightPx(latinTitle, density, scaledDensity, true), latinPx);
        assertEquals(expectedTabLabelHeightPx(burmeseTitle, density, scaledDensity, true), burmesePx);
        int latinLinePx = titleLineHeightPx(latinTitle, scaledDensity, true);
        int burmeseLinePx = titleLineHeightPx(burmeseTitle, scaledDensity, true);
        assertTrue(burmesePx >= latinPx);
        assertEquals(Math.max(minPx, latinLinePx), latinPx);
        assertEquals(Math.max(minPx, burmeseLinePx), burmesePx);
        if (burmesePx > latinPx && burmesePx > minPx) {
            assertTrue(burmesePx > latinPx);
        }
        if (burmeseLinePx > latinLinePx) {
            assertTrue(burmeseLinePx > latinLinePx);
        } else {
            assertNotEquals(titleLineHeightPx(null, scaledDensity, true), burmeseLinePx);
        }
        int maxPx = TabbarLabelSupport.maxTabLabelHeightPx(new String[] { latinTitle, burmeseTitle }, density, scaledDensity);
        assertEquals(Math.max(latinPx, burmesePx), maxPx);
    }

    private static int expectedTabLabelHeightPx(String title, float density, float scaledDensity, boolean bold) {
        int linePx = titleLineHeightPx(title, scaledDensity, bold);
        return Math.max(Math.round(TabbarLabelSupport.TAB_LABEL_MIN_HEIGHT_DP * density), linePx);
    }

    private static int titleLineHeightPx(String title, float scaledDensity, boolean bold) {
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setTypeface(Typeface.create(Typeface.DEFAULT, bold ? Typeface.BOLD : Typeface.NORMAL));
        paint.setTextSize(TabbarLabelSupport.TAB_LABEL_TEXT_SP * scaledDensity);
        Paint.FontMetricsInt metrics = new Paint.FontMetricsInt();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && title != null && !title.isEmpty()) {
            paint.getFontMetricsInt(title, 0, title.length(), 0, title.length(), false, metrics);
        } else {
            paint.getFontMetricsInt(metrics);
        }
        return metrics.bottom - metrics.top;
    }

    private static void applyFontScale(float fontScale) {
        Configuration configuration = new Configuration(RuntimeEnvironment.getApplication().getResources().getConfiguration());
        configuration.fontScale = fontScale;
        RuntimeEnvironment.getApplication().getResources().updateConfiguration(configuration, RuntimeEnvironment.getApplication().getResources().getDisplayMetrics());
    }

    private static int dp(int value) {
        return Math.round(value * RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().density);
    }
}
