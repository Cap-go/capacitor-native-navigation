package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import android.content.res.Configuration;
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
    public void burmeseTitleNeedsAtLeastAsMuchHeightAsLatinAtLargeFontScale() {
        applyFontScale(FONT_SCALE);
        float density = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().density;
        float scaledDensity = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().scaledDensity;
        int latinPx = TabbarLabelSupport.tabLabelHeightPxForTitle("Home", density, scaledDensity, true);
        int burmesePx = TabbarLabelSupport.tabLabelHeightPxForTitle("ကြိုဆိုပါသည်", density, scaledDensity, true);
        assertTrue(burmesePx >= latinPx);
        int maxPx = TabbarLabelSupport.maxTabLabelHeightPx(new String[] { "Home", "ကြိုဆိုပါသည်" }, density, scaledDensity);
        assertEquals(burmesePx, maxPx);
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
