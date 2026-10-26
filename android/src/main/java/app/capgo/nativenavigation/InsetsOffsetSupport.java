package app.capgo.nativenavigation;

/** Pure helpers for system-bar inset math when Capacitor offsets the WebView (unit tested). */
public final class InsetsOffsetSupport {

    private InsetsOffsetSupport() {}

    /**
     * How far the visible web content is already inset from the top of the window. Capacitor SystemBars may
     * move {@code android.R.id.content} or, on API 35+ with WebView &lt; 140, pad the WebView's parent instead.
     */
    public static int effectiveTopOffset(int contentRootTopInWindow, int webViewTopInWindow) {
        return Math.max(Math.max(0, contentRootTopInWindow), Math.max(0, webViewTopInWindow));
    }

    /** Gap between the bottom of the laid-out chrome and the bottom of the window decor. */
    public static int effectiveBottomOffset(int contentRootBottomGap, int webViewBottomGap) {
        return Math.max(Math.max(0, contentRootBottomGap), Math.max(0, webViewBottomGap));
    }

    public static int adjustedSystemBarInset(int rawInset, int effectiveOffset) {
        return Math.max(0, rawInset - effectiveOffset);
    }

    /**
     * {@link androidx.swiperefreshlayout.widget.SwipeRefreshLayout} replaces the WebView in its parent, so progress
     * offsets are relative to the WebView's top in window coordinates, not {@code android.R.id.content}.
     */
    public static int pullToRefreshProgressTopOffset(int navbarBottomInWindow, int webViewTopInWindow) {
        return Math.max(0, navbarBottomInWindow - Math.max(0, webViewTopInWindow));
    }

    /** WebView position affects JS insets and pull-to-refresh even when native bars are hidden. */
    public static boolean shouldUpdateOnWebViewBoundsChange(
        boolean navbarVisible,
        boolean tabbarVisible,
        boolean pullToRefreshEnabled
    ) {
        return navbarVisible || tabbarVisible || pullToRefreshEnabled;
    }
}
