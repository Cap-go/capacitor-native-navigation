package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

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
    public void floatingOutlineModeUsesShapePathAndGlassClip() {
        TabbarChromeSupport.TabbarOutlineMode mode = TabbarChromeSupport.outlineModeForShape("floating");
        assertEquals(TabbarChromeSupport.TabbarOutlineMode.FLOATING_SHAPE, mode);
        assertTrue(TabbarChromeSupport.shouldClipGlassToOutline(mode));
    }

    @Test
    public void curveOutlineModeUsesDefaultOutlineWithoutGlassClip() {
        TabbarChromeSupport.TabbarOutlineMode mode = TabbarChromeSupport.outlineModeForShape("curve");
        assertEquals(TabbarChromeSupport.TabbarOutlineMode.CURVE_DEFAULT, mode);
        assertFalse(TabbarChromeSupport.shouldClipGlassToOutline(mode));
    }

    @Test
    public void outlineModeSwitchesWhenShapeChanges() {
        assertEquals(
            TabbarChromeSupport.TabbarOutlineMode.FLOATING_SHAPE,
            TabbarChromeSupport.outlineModeForShape("floating")
        );
        assertEquals(
            TabbarChromeSupport.TabbarOutlineMode.CURVE_DEFAULT,
            TabbarChromeSupport.outlineModeForShape("curve")
        );
        assertEquals(
            TabbarChromeSupport.TabbarOutlineMode.FLOATING_SHAPE,
            TabbarChromeSupport.outlineModeForShape("floating")
        );
    }

    @Test
    public void floatingCapsuleWidthRespectsDetachedTrailingGap() {
        assertEquals(400, TabbarChromeSupport.floatingCapsuleWidth(480, 64, 16, true));
        assertEquals(480, TabbarChromeSupport.floatingCapsuleWidth(480, 64, 16, false));
    }

    @Test
    public void floatingCapsuleWidthHonorsCustomCornerRadiusInputs() {
        int width = 320;
        int barHeight = 56;
        int gap = 10;
        assertEquals(254, TabbarChromeSupport.floatingCapsuleWidth(width, barHeight, gap, true));
    }
}
