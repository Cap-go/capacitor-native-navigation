package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.json.JSONArray;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public class NavbarToolbarItemsSupportTest {

    @Test
    public void promotesLeadingLeftItemOnlyWithoutBackButton() {
        assertTrue(NavbarToolbarItemsSupport.shouldPromoteLeadingLeftItemToNavigation(false));
        assertFalse(NavbarToolbarItemsSupport.shouldPromoteLeadingLeftItemToNavigation(true));
    }

    @Test
    public void findsFirstLeftItemWithIcon() throws Exception {
        JSONArray items = new JSONArray(
            "["
                + "{\"id\":\"text\",\"title\":\"Menu\"},"
                + "{\"id\":\"menu\",\"title\":\"Menu\",\"icon\":{\"svg\":\"<svg viewBox=\\\"0 0 24 24\\\"></svg>\"}},"
                + "{\"id\":\"add\",\"title\":\"Add\",\"icon\":{\"svg\":\"<svg viewBox=\\\"0 0 24 24\\\"></svg>\"}}"
                + "]"
        );
        assertEquals(1, NavbarToolbarItemsSupport.indexOfFirstLeftItemWithIcon(items));
    }

    @Test
    public void skipsItemsWithoutRenderableIcon() throws Exception {
        JSONArray items = new JSONArray(
            "[{\"id\":\"menu\",\"title\":\"Menu\",\"icon\":{}},{\"id\":\"plain\",\"title\":\"Plain\"}]"
        );
        assertEquals(-1, NavbarToolbarItemsSupport.indexOfFirstLeftItemWithIcon(items));
    }
}
