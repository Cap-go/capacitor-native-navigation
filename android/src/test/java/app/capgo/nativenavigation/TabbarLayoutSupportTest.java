package app.capgo.nativenavigation;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class TabbarLayoutSupportTest {

    @Test
    public void isRtlLayoutDirectionRecognizesRtl() {
        assertTrue(TabbarLayoutSupport.isRtlLayoutDirection("rtl"));
        assertFalse(TabbarLayoutSupport.isRtlLayoutDirection("ltr"));
        assertFalse(TabbarLayoutSupport.isRtlLayoutDirection(null));
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
}
