package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class InsetsOffsetSupportTest {

    @Test
    public void effectiveTopOffsetUsesWebViewWhenContentRootStaysAtZero() {
        assertEquals(50, InsetsOffsetSupport.effectiveTopOffset(0, 50));
        assertEquals(0, InsetsOffsetSupport.adjustedSystemBarInset(50, InsetsOffsetSupport.effectiveTopOffset(0, 50)));
    }

    @Test
    public void nativeChromeInsetIgnoresWebViewOffsetWhenContentRootStaysAtZero() {
        assertEquals(50, InsetsOffsetSupport.adjustedSystemBarInset(50, 0));
    }

    @Test
    public void effectiveTopOffsetUsesContentRootWhenItMoves() {
        assertEquals(50, InsetsOffsetSupport.effectiveTopOffset(50, 0));
        assertEquals(0, InsetsOffsetSupport.adjustedSystemBarInset(50, InsetsOffsetSupport.effectiveTopOffset(50, 0)));
    }

    @Test
    public void effectiveTopOffsetIsZeroWhenNeitherViewIsOffset() {
        assertEquals(0, InsetsOffsetSupport.effectiveTopOffset(0, 0));
        assertEquals(50, InsetsOffsetSupport.adjustedSystemBarInset(50, InsetsOffsetSupport.effectiveTopOffset(0, 0)));
    }

    @Test
    public void effectiveTopOffsetTakesMaximumOfBothSources() {
        assertEquals(106, InsetsOffsetSupport.effectiveTopOffset(50, 106));
        assertEquals(0, InsetsOffsetSupport.adjustedSystemBarInset(50, 106));
    }

    @Test
    public void effectiveBottomOffsetUsesWebViewWhenContentRootStaysAtZero() {
        assertEquals(24, InsetsOffsetSupport.effectiveBottomOffset(0, 24));
        assertEquals(0, InsetsOffsetSupport.adjustedSystemBarInset(24, InsetsOffsetSupport.effectiveBottomOffset(0, 24)));
    }

    @Test
    public void effectiveBottomOffsetUsesContentRootWhenItIsInset() {
        assertEquals(24, InsetsOffsetSupport.effectiveBottomOffset(24, 0));
        assertEquals(0, InsetsOffsetSupport.adjustedSystemBarInset(24, InsetsOffsetSupport.effectiveBottomOffset(24, 0)));
    }

    @Test
    public void adjustedSystemBarInsetNeverReturnsNegative() {
        assertEquals(0, InsetsOffsetSupport.adjustedSystemBarInset(24, 100));
    }

    @Test
    public void pullToRefreshOffsetSubtractsWebViewTopWhenWebViewStartsBelowWindowOrigin() {
        int navbarBottomInWindow = 50 + 56;
        assertEquals(56, InsetsOffsetSupport.pullToRefreshProgressTopOffset(navbarBottomInWindow, 50));
    }

    @Test
    public void pullToRefreshOffsetUsesNavbarBottomWhenWebViewAlignsWithWindowOrigin() {
        int navbarBottomInWindow = 50 + 56;
        assertEquals(106, InsetsOffsetSupport.pullToRefreshProgressTopOffset(navbarBottomInWindow, 0));
    }
}
