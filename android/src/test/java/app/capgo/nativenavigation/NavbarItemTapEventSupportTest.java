package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class NavbarItemTapEventSupportTest {

    @Test
    public void buildsLeadingLeftTapPayload() {
        NavbarItemTapEventSupport.NavbarItemTapPayload payload = NavbarItemTapEventSupport.leadingLeft("menu", "Menu");
        assertEquals("menu", payload.id);
        assertEquals("Menu", payload.title);
        assertEquals("left", payload.placement);
    }
}
