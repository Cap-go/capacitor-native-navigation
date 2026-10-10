package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class NavbarScrollSupportTest {

    @Test
    public void parseBehaviorDefaultsToNone() {
        assertEquals(NavbarScrollSupport.ScrollBehavior.NONE, NavbarScrollSupport.parseBehavior(null));
        assertEquals(NavbarScrollSupport.ScrollBehavior.NONE, NavbarScrollSupport.parseBehavior("invalid"));
    }

    @Test
    public void bothHidesOnScrollDownAndRevealsOnScrollUp() {
        assertEquals(
            NavbarScrollSupport.ScrollAction.HIDE,
            NavbarScrollSupport.scrollAction(NavbarScrollSupport.ScrollBehavior.BOTH, 120f, 20f, 8f, false)
        );
        assertEquals(
            NavbarScrollSupport.ScrollAction.REVEAL,
            NavbarScrollSupport.scrollAction(NavbarScrollSupport.ScrollBehavior.BOTH, 120f, -20f, 8f, true)
        );
    }

    @Test
    public void hideOnScrollDownRevealsAtTop() {
        assertEquals(
            NavbarScrollSupport.ScrollAction.REVEAL,
            NavbarScrollSupport.scrollAction(NavbarScrollSupport.ScrollBehavior.HIDE_ON_SCROLL_DOWN, 0f, 0f, 8f, true)
        );
    }

    @Test
    public void revealOnScrollUpDoesNotHideOnScrollDown() {
        assertEquals(
            NavbarScrollSupport.ScrollAction.NONE,
            NavbarScrollSupport.scrollAction(NavbarScrollSupport.ScrollBehavior.REVEAL_ON_SCROLL_UP, 120f, 20f, 8f, false)
        );
    }
}
