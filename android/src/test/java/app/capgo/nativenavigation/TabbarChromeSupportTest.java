package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import android.graphics.Color;
import org.junit.Test;

public class TabbarChromeSupportTest {

    @Test
    public void resolveSelectedIndicatorColorUsesExplicitColor() {
        int explicit = Color.rgb(10, 20, 30);
        assertEquals(explicit, TabbarChromeSupport.resolveSelectedIndicatorColor(explicit, Color.BLUE));
    }

    @Test
    public void resolveSelectedIndicatorColorFallsBackToTintAlpha() {
        int tint = Color.rgb(61, 95, 255);
        int expected = Color.argb(34, 61, 95, 255);
        assertEquals(expected, TabbarChromeSupport.resolveSelectedIndicatorColor(null, tint));
    }

    @Test
    public void floatingPillOutlineRadiusUsesHalfHeight() {
        assertEquals(32f, TabbarChromeSupport.floatingPillOutlineRadius(64f));
    }
}
