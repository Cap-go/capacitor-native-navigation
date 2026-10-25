package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class NavbarSearchSupportTest {

    @Test
    public void rowHeightIsZeroWhenHiddenOrCollapsed() {
        assertEquals(0, NavbarSearchSupport.rowHeightDp(false, true, false));
        assertEquals(52, NavbarSearchSupport.rowHeightDp(true, true, false));
        assertEquals(0, NavbarSearchSupport.rowHeightDp(true, true, true));
        assertEquals(52, NavbarSearchSupport.rowHeightDp(true, false, true));
        assertEquals(NavbarSearchSupport.ROW_HEIGHT_DP, 52);
    }

    @Test
    public void hidesWhenCollapsedFollowsTheLargeTitleWhenOmitted() {
        assertTrue(NavbarSearchSupport.hidesWhenCollapsed(null, true));
        assertFalse(NavbarSearchSupport.hidesWhenCollapsed(null, false));
        assertFalse(NavbarSearchSupport.hidesWhenCollapsed(Boolean.FALSE, true));
        assertTrue(NavbarSearchSupport.hidesWhenCollapsed(Boolean.TRUE, false));
    }

    @Test
    public void focusedSearchKeepsKeystrokesUntilTheSuppliedTextChanges() {
        assertFalse(NavbarSearchSupport.shouldApplyText(true, "he", "h", "h"));
        assertTrue(NavbarSearchSupport.shouldApplyText(true, "hello", "", "hello"));
        assertFalse(NavbarSearchSupport.shouldApplyText(true, "h", "h", null));
        assertTrue(NavbarSearchSupport.shouldApplyText(false, "he", "h", "h"));
    }
}
