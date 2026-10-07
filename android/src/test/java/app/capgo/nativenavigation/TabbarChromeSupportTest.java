package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class TabbarChromeSupportTest {

    @Test
    public void resolveSelectedIndicatorColorUsesExplicitColor() {
        int explicit = 0xFF0A141E;
        assertEquals(explicit, TabbarChromeSupport.resolveSelectedIndicatorColor(explicit, 0xFF0000FF));
    }

    @Test
    public void resolveSelectedIndicatorColorFallsBackToTintAlpha() {
        int tint = 0xFF3D5FFF;
        int expected = 0x223D5FFF;
        assertEquals(expected, TabbarChromeSupport.resolveSelectedIndicatorColor(null, tint));
    }

    @Test
    public void floatingPillOutlineRadiusUsesHalfHeight() {
        assertEquals(32f, TabbarChromeSupport.floatingPillOutlineRadius(64f), 0.001f);
    }
}
