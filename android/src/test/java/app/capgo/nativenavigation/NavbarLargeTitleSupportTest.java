package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class NavbarLargeTitleSupportTest {

    @Test
    public void barHeightGrowsWithTheLargeTitleRow() {
        assertEquals(56f, NavbarLargeTitleSupport.barHeightDp(0f), 0.001f);
        assertEquals(108f, NavbarLargeTitleSupport.barHeightDp(1f), 0.001f);
        assertEquals(82f, NavbarLargeTitleSupport.barHeightDp(0.5f), 0.001f);
        assertEquals(108f, NavbarLargeTitleSupport.barHeightDp(3f), 0.001f);
    }

    @Test
    public void titlesNeverShowTogether() {
        assertEquals(1f, NavbarLargeTitleSupport.largeTitleAlpha(1f), 0.001f);
        assertEquals(0f, NavbarLargeTitleSupport.inlineTitleAlpha(1f), 0.001f);
        assertEquals(0f, NavbarLargeTitleSupport.largeTitleAlpha(0.5f), 0.001f);
        assertEquals(0f, NavbarLargeTitleSupport.inlineTitleAlpha(0.5f), 0.001f);
        assertEquals(0f, NavbarLargeTitleSupport.largeTitleAlpha(0f), 0.001f);
        assertEquals(1f, NavbarLargeTitleSupport.inlineTitleAlpha(0f), 0.001f);
    }

    @Test
    public void animatesOnlyCollapseOfTheSamePage() {
        assertTrue(NavbarLargeTitleSupport.shouldAnimate(true, "Teams", "Teams", true, false));
        assertTrue(NavbarLargeTitleSupport.shouldAnimate(true, "Teams", "Teams", false, true));
        assertFalse(NavbarLargeTitleSupport.shouldAnimate(true, "Teams", "Rules", true, false));
        assertFalse(NavbarLargeTitleSupport.shouldAnimate(false, "Teams", "Teams", true, false));
        assertFalse(NavbarLargeTitleSupport.shouldAnimate(true, "Teams", "Teams", true, true));
    }
}
