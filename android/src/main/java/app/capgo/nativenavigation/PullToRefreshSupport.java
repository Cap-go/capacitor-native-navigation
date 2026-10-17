package app.capgo.nativenavigation;

import android.view.View;
import android.view.ViewGroup;
import androidx.swiperefreshlayout.widget.SwipeRefreshLayout;

/**
 * Optional native pull-to-refresh. The WebView is wrapped in a {@link SwipeRefreshLayout} only while the
 * feature is enabled and put back exactly where it was when disabled, so apps that never opt in keep
 * Capacitor's original view tree.
 */
final class PullToRefreshSupport {

    interface Listener {
        void onRefresh();
    }

    private SwipeRefreshLayout layout;
    private View webView;
    /** Last scroll offset reported by the page, so inner scroll roots (like `#app`) block the gesture too. */
    private float webScrollOffsetY = 0f;

    boolean isEnabled() {
        return layout != null;
    }

    void enable(View webView, Listener listener) {
        if (layout != null && this.webView == webView) {
            return;
        }
        disable();
        ViewGroup parent = webView.getParent() instanceof ViewGroup ? (ViewGroup) webView.getParent() : null;
        if (parent == null) {
            return;
        }
        int index = parent.indexOfChild(webView);
        ViewGroup.LayoutParams params = webView.getLayoutParams();
        SwipeRefreshLayout refreshLayout = new SwipeRefreshLayout(webView.getContext());
        refreshLayout.setOnRefreshListener(listener::onRefresh);
        refreshLayout.setOnChildScrollUpCallback((swipeLayout, child) -> canScrollUp(webView, webScrollOffsetY));
        parent.removeViewAt(index);
        refreshLayout.addView(webView, new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        parent.addView(refreshLayout, index, params);
        this.layout = refreshLayout;
        this.webView = webView;
        webScrollOffsetY = 0f;
    }

    void disable() {
        if (layout == null) {
            return;
        }
        SwipeRefreshLayout refreshLayout = layout;
        View view = webView;
        layout = null;
        webView = null;
        refreshLayout.setRefreshing(false);
        ViewGroup parent = refreshLayout.getParent() instanceof ViewGroup ? (ViewGroup) refreshLayout.getParent() : null;
        if (parent == null || view == null) {
            return;
        }
        int index = parent.indexOfChild(refreshLayout);
        ViewGroup.LayoutParams params = refreshLayout.getLayoutParams();
        refreshLayout.removeView(view);
        parent.removeViewAt(index);
        parent.addView(view, index, params);
    }

    void setRefreshing(boolean refreshing) {
        if (layout != null) {
            layout.setRefreshing(refreshing);
        }
    }

    void setColors(Integer spinnerColor, Integer backgroundColor) {
        if (layout == null) {
            return;
        }
        if (spinnerColor != null) {
            layout.setColorSchemeColors(spinnerColor);
        }
        if (backgroundColor != null) {
            layout.setProgressBackgroundColorSchemeColor(backgroundColor);
        }
    }

    /** Keeps the spinner below the native navbar instead of behind it. */
    void setTopOffset(int topPx) {
        if (layout == null) {
            return;
        }
        int size = layout.getProgressCircleDiameter();
        layout.setProgressViewOffset(false, topPx - size, topPx + Math.round(size * 1.5f));
    }

    void reportWebScroll(float offsetY) {
        webScrollOffsetY = offsetY;
    }

    void resetWebScroll() {
        webScrollOffsetY = 0f;
    }

    static boolean canScrollUp(View webView, float reportedOffsetY) {
        return reportedOffsetY > 0.5f || webView.canScrollVertically(-1);
    }
}
