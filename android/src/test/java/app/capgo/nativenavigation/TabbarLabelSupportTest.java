package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class TabbarLabelSupportTest {

    private static final int DENSITY_3X_MIN_LABEL_PX = 54;

    @Test
    public void tabbarExtraHeightZeroWhenLabelUsesMinimum() {
        assertEquals(0, TabbarLabelSupport.tabbarExtraHeightPx(DENSITY_3X_MIN_LABEL_PX, DENSITY_3X_MIN_LABEL_PX));
    }

    @Test
    public void tabbarExtraHeightMatchesLabelGrowth() {
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
}
