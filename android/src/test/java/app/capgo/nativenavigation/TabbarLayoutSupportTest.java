package app.capgo.nativenavigation;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.view.View;

import org.junit.Test;

public class TabbarLayoutSupportTest {

    @Test
    public void viewLayoutDirectionInheritsWhenOptionOmitted() {
        assertEquals(View.LAYOUT_DIRECTION_INHERIT, TabbarLayoutSupport.viewLayoutDirectionForTabbarOption(null));
        assertEquals(View.LAYOUT_DIRECTION_INHERIT, TabbarLayoutSupport.viewLayoutDirectionForTabbarOption("auto"));
        assertEquals(View.LAYOUT_DIRECTION_RTL, TabbarLayoutSupport.viewLayoutDirectionForTabbarOption("rtl"));
        assertEquals(View.LAYOUT_DIRECTION_LTR, TabbarLayoutSupport.viewLayoutDirectionForTabbarOption("ltr"));
    }

    @Test
    public void isRtlLayoutDirectionRecognizesRtl() {
        assertTrue(TabbarLayoutSupport.isRtlLayoutDirection("rtl"));
        assertFalse(TabbarLayoutSupport.isRtlLayoutDirection("ltr"));
        assertFalse(TabbarLayoutSupport.isRtlLayoutDirection(null));
        assertFalse(TabbarLayoutSupport.isRtlLayoutDirection("auto"));
    }

    @Test
    public void trailingActionLeftFlipsForRtl() {
        assertEquals(416, TabbarLayoutSupport.trailingActionLeft(480, 64, false));
        assertEquals(0, TabbarLayoutSupport.trailingActionLeft(480, 64, true));
    }

    @Test
    public void capsuleLeftForDetachedTrailingFlipsForRtl() {
        assertEquals(0, TabbarLayoutSupport.capsuleLeftForDetachedTrailing(64, 10, false));
        assertEquals(74, TabbarLayoutSupport.capsuleLeftForDetachedTrailing(64, 10, true));
    }

    @Test
    public void slotLeftsLtrPlacesFromLeadingEdge() {
        assertArrayEquals(new int[] { 0, 100, 220 }, TabbarLayoutSupport.slotLefts(0, 300, new int[] { 100, 120, 80 }, false));
    }

    @Test
    public void slotLeftsRtlPlacesFromTrailingEdge() {
        assertArrayEquals(new int[] { 220, 100, 0 }, TabbarLayoutSupport.slotLefts(0, 300, new int[] { 80, 120, 100 }, true));
    }

    @Test
    public void dragRangeContainsUsesFullTabSpan() {
        float[] centers = new float[] { 250f, 150f, 50f };
        float[] widths = new float[] { 80f, 80f, 80f };
        assertTrue(TabbarLayoutSupport.dragRangeContains(250f, centers, widths));
        assertTrue(TabbarLayoutSupport.dragRangeContains(50f, centers, widths));
        assertFalse(TabbarLayoutSupport.dragRangeContains(5f, centers, widths));
    }

    @Test
    public void dragPositionAtRtlMapsRightmostTabToIndexZero() {
        float[] centers = new float[] { 250f, 150f, 50f };
        assertEquals(0f, TabbarLayoutSupport.dragPositionAt(260f, centers, true), 0.001f);
        assertEquals(2f, TabbarLayoutSupport.dragPositionAt(40f, centers, true), 0.001f);
        assertEquals(1f, TabbarLayoutSupport.dragPositionAt(150f, centers, true), 0.001f);
    }
}
