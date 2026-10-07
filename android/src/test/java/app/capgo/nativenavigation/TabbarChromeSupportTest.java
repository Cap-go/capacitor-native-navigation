package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class TabbarChromeSupportTest {

    @Test
    public void tabbarSlideDistanceUsesMeasuredHeight() {
        assertEquals(120f, TabbarChromeSupport.tabbarSlideDistancePx(100, 20, 80), 0.001f);
    }

    @Test
    public void tabbarSlideDistanceFallsBackWhenUnmeasured() {
        assertEquals(84f, TabbarChromeSupport.tabbarSlideDistancePx(0, 0, 84), 0.001f);
    }
}
