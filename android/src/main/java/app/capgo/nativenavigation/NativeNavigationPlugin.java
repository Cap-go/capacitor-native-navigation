package app.capgo.nativenavigation;

import android.animation.Animator;
import android.animation.AnimatorListenerAdapter;
import android.animation.ValueAnimator;
import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Outline;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.Rect;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.InsetDrawable;
import android.os.Build;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.HapticFeedbackConstants;
import android.view.Menu;
import android.view.MenuItem;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.view.Window;
import android.view.WindowInsets;
import android.text.Editable;
import android.text.InputType;
import android.text.TextWatcher;
import android.view.animation.PathInterpolator;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.appcompat.content.res.AppCompatResources;
import androidx.appcompat.widget.Toolbar;
import androidx.core.graphics.PathParser;
import androidx.core.view.MenuItemCompat;
import androidx.core.widget.TextViewCompat;
import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.StringReader;
import java.net.URLDecoder;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.json.JSONArray;
import org.json.JSONObject;
import org.xmlpull.v1.XmlPullParser;
import org.xmlpull.v1.XmlPullParserFactory;

@CapacitorPlugin(name = "NativeNavigation")
public class NativeNavigationPlugin extends Plugin {

    private static final int DEFAULT_NAVBAR_DP = 56;
    private static final int DEFAULT_TABBAR_DP = 64;
    private static final int TAB_LABEL_TEXT_SP = 12;
    private static final int TAB_CONTENT_PADDING_DP = 4;
    private static final int INDICATOR_HORIZONTAL_PADDING_DP = 12;
    private static final int INDICATOR_VERTICAL_PADDING_DP = 6;
    private static final int INDICATOR_SLOT_INSET_DP = 2;
    private static final int FLOATING_INDICATOR_INSET_DP = 4;
    private static final int DEFAULT_TRANSITION_MS = 350;
    private static final int TAB_LABEL_HEIGHT_DP = 18;
    private static final int TAB_ICON_LABEL_GAP_DP = 2;
    private static final int TABBAR_MINIMIZE_HEIGHT_REDUCTION_DP = 16;
    private static final int TABBAR_MINIMIZE_SIDE_INSET_DP = 24;
    private static final int TABBAR_MINIMIZE_ANIMATION_MS = 280;
    private static final int TAB_INDICATOR_SLIDE_MS = 260;
    private static final int MENU_ITEM_BASE = 10_000;
    private static final int DEFAULT_TABBAR_BACKGROUND_COLOR = Color.WHITE;

    private final NativeNavigation implementation = new NativeNavigation();
    private FrameLayout navbarContainer;
    private FrameLayout tabbarContainer;
    private View tabbarBackdrop;
    private Toolbar toolbar;
    private NativeTabbarLayout tabbar;
    private View navbarGlassSurface;
    private View tabbarGlassSurface;
    private ImageView transitionSnapshot;
    private boolean enabled = true;
    private boolean navbarVisible = false;
    private NavbarScrollSupport.ScrollBehavior navbarScrollBehavior = NavbarScrollSupport.ScrollBehavior.NONE;
    private float navbarScrollThreshold = 8f;
    private boolean navbarScrollCollapsed = false;
    private TextView largeTitleView;
    private NavbarSegmentRows navbarSegments;
    private EditText navbarSearchField;
    private boolean navbarSearchVisible = false;
    private boolean navbarSearchHidesWhenCollapsed = false;
    private boolean navbarSearchCollapsed = false;
    private boolean navbarSearchApplying = false;
    /** Last {@code search.text} from {@code setNavbar}. Null after the row is hidden. */
    private String navbarSearchSuppliedText;
    private boolean navbarLarge = false;
    private float navbarLargeProgress = 0f;
    private ValueAnimator navbarLargeAnimator;
    private String navbarTitle;
    private int navbarForegroundColor = Color.rgb(20, 24, 32);
    private boolean tabbarVisible = false;
    private String contentInsetMode = "css";
    private GlassOptions defaultGlassOptions = GlassOptions.defaults();
    private boolean configureSpecifiedGlassEffect = false;
    private GlassOptions navbarGlassOptions = GlassOptions.defaults();
    private GlassOptions tabbarGlassOptions = GlassOptions.defaults();
    private JSObject navbarGlassConfig;
    private JSObject tabbarGlassConfig;
    private int defaultTransitionMs = DEFAULT_TRANSITION_MS;
    private int activeTransitionMs = DEFAULT_TRANSITION_MS;
    private int tintColor = Color.rgb(0, 122, 255);
    private int inactiveTintColor = Color.rgb(120, 126, 137);
    private int navbarBackgroundColor = Color.argb(225, 255, 255, 255);
    private int tabbarBackgroundColor = Color.argb(235, 255, 255, 255);
    private int badgeBackgroundColor = Color.rgb(255, 59, 48);
    private int badgeTextColor = Color.WHITE;
    private TabbarStyle tabbarStyle = TabbarStyle.defaults(Color.rgb(0, 122, 255));
    private String activeTransitionId;
    private String activeTransitionDirection = "forward";
    private RectF activeZoomSourceFrame;
    private float activeZoomCornerRadius = 0f;
    private Drawable activeTransitionRootBackground;
    private boolean activeTransitionRootBackgroundCaptured = false;
    private final Map<Integer, String> menuActionIds = new HashMap<>();
    private final Map<Integer, String> menuActionTitles = new HashMap<>();
    private final Map<Integer, String> menuActionPlacements = new HashMap<>();
    private final List<NativeTabItem> tabItems = new ArrayList<>();
    private int selectedTabIndex = 0;
    private boolean tabbarChromeHideAnimating = false;
    private boolean tabbarDisableIndicator = false;
    private Integer tabbarIndicatorColor = null;
    private String tabbarLabelVisibilityMode = "labeled";
    private boolean tabbarIconsVisible = true;
    private boolean tabbarMinimizeOnScroll = false;
    private boolean tabbarDragToSelect = true;
    private boolean tabbarEdgeBlur = false;
    private boolean navbarEdgeBlur = false;
    private boolean tabbarMinimized = false;
    private float tabbarMinimizeProgress = 0f;
    private ValueAnimator tabbarMinimizeAnimator;
    private final PullToRefreshSupport pullToRefresh = new PullToRefreshSupport();
    private boolean webViewBoundsWatcherAttached;
    private static final int WEB_VIEW_BOUNDS_WATCHER_MAX_ATTACH_ATTEMPTS = 60;
    private static final long WEB_VIEW_BOUNDS_WATCHER_RETRY_DELAY_MS = 100L;
    private int webViewBoundsWatcherAttachAttempts;
    private Runnable pendingWebViewBoundsWatcherAttach;

    @Override
    public void load() {
        Activity activity = getActivity();
        if (activity != null) {
            activity.runOnUiThread(() -> {
                enableEdgeToEdge();
                watchContentRootBounds();
            });
        }
    }

    @Override
    protected void handleOnDestroy() {
        cancelPendingWebViewBoundsWatcherAttach();
        super.handleOnDestroy();
    }

    @PluginMethod
    public void configure(PluginCall call) {
        runOnUiThread(() -> {
            enabled = call.getBoolean("enabled", true);
            contentInsetMode = call.getString("contentInsetMode", contentInsetMode);
            JSObject configureGlass = call.getObject("glass", null);
            if (configureGlass != null && configureGlass.has("effect")) {
                configureSpecifiedGlassEffect = true;
            }
            defaultGlassOptions = GlassOptions.from(configureGlass, defaultGlassOptions);
            navbarGlassOptions = GlassOptions.from(navbarGlassConfig, defaultGlassOptions);
            tabbarGlassOptions = resolveTabbarGlassOptions(call);
            Double duration = call.getDouble("animationDuration");
            if (duration != null) {
                defaultTransitionMs = Math.max(0, duration.intValue());
            }
            if (!enabled) {
                navbarVisible = false;
                tabbarVisible = false;
                if (navbarContainer != null) {
                    navbarContainer.setVisibility(View.GONE);
                }
                if (tabbar != null) {
                    tabbar.setVisibility(View.GONE);
                }
                if (tabbarContainer != null) {
                    tabbarContainer.setVisibility(View.GONE);
                }
                if (tabbarBackdrop != null) {
                    tabbarBackdrop.setVisibility(View.GONE);
                }
            }
            if (enabled) {
                reapplyVisibleChromeBackgrounds();
            }
            updateInsetsAndNotify();
            call.resolve(insetsResult());
        });
    }

    @PluginMethod
    public void setNavbar(PluginCall call) {
        runOnUiThread(() -> {
            if (!enabled) {
                navbarVisible = false;
                stopNavbarScrollObservation(true);
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            boolean hidden = call.getBoolean("hidden", false);
            navbarVisible = !hidden;
            navbarEdgeBlur = Boolean.TRUE.equals(call.getBoolean("edgeBlur", false));
            if (hidden) {
                navbarSearchVisible = false;
                navbarSearchCollapsed = false;
                navbarSearchSuppliedText = null;
                if (navbarSearchField != null) {
                    navbarSearchField.setVisibility(View.GONE);
                }
                if (navbarContainer != null) {
                    navbarContainer.setVisibility(View.GONE);
                }
                stopNavbarScrollObservation(true);
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            Toolbar nativeToolbar = ensureToolbar();
            String title = call.getString("title", "");
            boolean large = Boolean.TRUE.equals(call.getBoolean("large", false));
            boolean animateLarge = NavbarLargeTitleSupport.shouldAnimate(
                navbarContainer.getVisibility() == View.VISIBLE,
                navbarTitle,
                title,
                navbarLarge,
                large
            );
            navbarTitle = title;
            navbarLarge = large;
            nativeToolbar.setTitle(title);
            largeTitleView.setText(title);
            nativeToolbar.setSubtitle(call.getString("subtitle", null));
            nativeToolbar.getMenu().clear();
            menuActionIds.clear();
            menuActionTitles.clear();
            menuActionPlacements.clear();

            JSObject backButton = call.getObject("backButton", null);
            if (backButton != null && Boolean.TRUE.equals(backButton.getBool("visible"))) {
                boolean close = "close".equals(backButton.getString("role", "back"));
                String provided = backButton.getString("title", null);
                if (provided == null || provided.isEmpty()) {
                    provided = close ? "Close" : "Back";
                }
                // Android has no vertical dock. Close uses the clear icon; search `placement: button` stays stacked.
                nativeToolbar.setNavigationIcon(
                    close
                        ? androidx.appcompat.R.drawable.abc_ic_clear_material
                        : androidx.appcompat.R.drawable.abc_ic_ab_back_material
                );
                nativeToolbar.setNavigationContentDescription(provided);
                nativeToolbar.setNavigationOnClickListener((v) -> notifyListeners("navbarBack", new JSObject().put("source", "navbar")));
                if (Boolean.TRUE.equals(backButton.getBool("supplements"))) {
                    addToolbarItems(nativeToolbar, call.getArray("leftItems", new JSArray()), "left");
                }
            } else {
                // Without a visible back button, the first left item with an icon takes the leading navigation slot,
                // like iOS. Any other left items stay in the toolbar menu.
                JSONArray leftItems = call.getArray("leftItems", new JSArray());
                boolean rtl = nativeToolbar.getLayoutDirection() == View.LAYOUT_DIRECTION_RTL;
                int leadingIndex = firstResolvableLeadingIconIndex(leftItems, rtl);
                if (leadingIndex >= 0) {
                    applyLeadingNavigationItem(nativeToolbar, leftItems.optJSONObject(leadingIndex));
                    leftItems = withoutIndex(leftItems, leadingIndex);
                } else {
                    nativeToolbar.setNavigationIcon(null);
                    nativeToolbar.setNavigationOnClickListener(null);
                    nativeToolbar.setNavigationContentDescription(null);
                }
                addToolbarItems(nativeToolbar, leftItems, "left");
            }

            addToolbarItems(nativeToolbar, call.getArray("rightItems", new JSArray()), "right");
            JSObject colors = call.getObject("colors", new JSObject());
            navbarGlassConfig = call.getObject("glass", null);
            navbarGlassOptions = GlassOptions.from(navbarGlassConfig, defaultGlassOptions);
            applyToolbarColors(nativeToolbar, colors);
            if (!large || Boolean.TRUE.equals(call.getBoolean("resetScrollCollapsed", false))) {
                navbarSearchCollapsed = false;
            }
            applyNavbarSearch(call.getObject("search", null), large);
            applyNavbarSegments(call.getArray("segments", new JSArray()));
            setNavbarLargeProgress(large ? 1f : 0f, animateLarge);
            navbarContainer.setVisibility(View.VISIBLE);
            configureNavbarScrollBehavior(call);
            layoutChrome();
            updateInsetsAndNotify();
            call.resolve(insetsResult());
        });
    }

    @PluginMethod
    public void reportNavbarScroll(PluginCall call) {
        runOnUiThread(() -> {
            float offsetY = call.getFloat("offsetY", 0f);
            float deltaY = call.getFloat("deltaY", 0f);
            pullToRefresh.reportWebScroll(offsetY);
            if (navbarScrollBehavior != NavbarScrollSupport.ScrollBehavior.NONE && navbarVisible) {
                handleNavbarScroll(offsetY, deltaY);
            }
            if (tabbarMinimizeEnabled() && tabbarVisible) {
                handleTabbarMinimizeScroll(offsetY, deltaY);
            }
            if (navbarLarge && navbarSearchHidesWhenCollapsed && navbarSearchVisible) {
                boolean collapsed = offsetY > 30f;
                if (collapsed != navbarSearchCollapsed) {
                    navbarSearchCollapsed = collapsed;
                    layoutChrome();
                    updateInsetsAndNotify();
                }
            }
            call.resolve();
        });
    }

    @PluginMethod
    public void setPullToRefresh(PluginCall call) {
        runOnUiThread(() -> {
            View webView = getBridge() == null ? null : getBridge().getWebView();
            if (webView == null) {
                call.reject("WebView unavailable");
                return;
            }
            if (!call.getBoolean("enabled", false)) {
                pullToRefresh.disable();
                call.resolve();
                return;
            }
            pullToRefresh.enable(webView, () -> notifyListeners("pullToRefresh", new JSObject()));
            pullToRefresh.setColors(
                parseColorOrNull(call.getString("tintColor", null)),
                parseColorOrNull(call.getString("backgroundColor", null))
            );
            pullToRefresh.setTopOffset(pullToRefreshTopPx());
            // Inner scroll roots (`#app`, marked elements) report offsets through the scroll bridge.
            startNavbarScrollObservation();
            call.resolve();
        });
    }

    @PluginMethod
    public void endPullToRefresh(PluginCall call) {
        runOnUiThread(() -> {
            pullToRefresh.setRefreshing(false);
            call.resolve();
        });
    }

    private int pullToRefreshTopPx() {
        int navbarToolbar = navbarScrollCollapsed ? 0 : navbarBarHeight(navbarLarge ? 1f : 0f) + navbarAccessoryHeight();
        int navbarBottomInWindow =
            contentRootTopOffset() + nativeStatusBarInset() + (navbarVisible ? navbarToolbar : 0);
        return InsetsOffsetSupport.pullToRefreshProgressTopOffset(navbarBottomInWindow, webViewTopOffset());
    }

    @PluginMethod
    public void setTabbar(PluginCall call) {
        runOnUiThread(() -> {
            if (!enabled) {
                tabbarVisible = false;
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            boolean hidden = call.getBoolean("hidden", false);
            boolean animated = call.getBoolean("animated", false);
            tabbarVisible = !hidden;
            if (hidden) {
                setTabbarMinimized(false, false);
                setTabbarChromeVisible(false, animated);
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            NativeTabbarLayout nativeTabbar = ensureTabbar();
            nativeTabbar.removeAllViews();
            tabItems.clear();
            selectedTabIndex = -1;

            boolean labels = call.getBoolean("labels", true);
            boolean icons = call.getBoolean("icons", true);
            String labelVisibilityMode = call.getString("labelVisibilityMode", labels ? "labeled" : "unlabeled");
            tabbarIconsVisible = icons;
            JSONArray tabs = call.getArray("tabs", new JSArray());
            String selectedId = call.getString("selectedId", null);
            JSObject colors = call.getObject("colors", new JSObject());
            tabbarGlassConfig = call.getObject("glass", null);
            badgeBackgroundColor = colorOption(call, colors, "badgeBackgroundColor", "badgeBackground", Color.rgb(255, 59, 48));
            badgeTextColor = colorOption(call, colors, "badgeTextColor", "badgeText", Color.WHITE);
            tabbarDisableIndicator = call.getBoolean("disableIndicator", false);
            tabbarIndicatorColor = colorOption(call, colors, "indicatorColor", "indicator", null);
            tabbarMinimizeOnScroll = "onScrollDown".equals(call.getString("minimizeBehavior", "never"));
            tabbarDragToSelect = call.getBoolean("dragToSelect", true);
            tabbarEdgeBlur = call.getBoolean("edgeBlur", false);

            for (int sourceIndex = 0; sourceIndex < tabs.length(); sourceIndex++) {
                JSONObject tab = tabs.optJSONObject(sourceIndex);
                if (tab == null) {
                    continue;
                }
                String id = tab.optString("id", "tab-" + sourceIndex);
                boolean isHidden = tab.optBoolean("hidden", false);
                if (isHidden && !id.equals(selectedId)) {
                    continue;
                }

                String title = tab.optString("title", "");
                Drawable icon = icons ? iconFrom(tab.optJSONObject("icon")) : new ColorDrawable(Color.TRANSPARENT);
                Drawable selectedIcon = icons ? iconFrom(tab.optJSONObject("selectedIcon")) : null;
                String badge = tab.has("badge") ? String.valueOf(tab.opt("badge")) : null;
                String role = tab.optString("role", "normal");
                boolean detachedTrailing = "search".equalsIgnoreCase(role) || "prominent".equalsIgnoreCase(role);
                tabItems.add(
                    new NativeTabItem(id, title, icon, selectedIcon, badge, tab.optBoolean("enabled", true), detachedTrailing, sourceIndex)
                );
            }

            applyTabbarColors(call, colors);
            tabbarStyle = makeTabbarStyle(call.getObject("style", new JSObject()));
            tabbarGlassOptions = resolveTabbarGlassOptions(call);
            nativeTabbar.applyLayoutDirection(call.getString("layoutDirection", null));

            // Keep at most one detached trailing action for floating bars.
            // Curve bars ignore role so tab order / center selection stay stable.
            if (!tabbarStyle.isCurve() && !tabbarStyle.isSidebar()) {
                NativeTabItem trailingItem = null;
                for (int index = tabItems.size() - 1; index >= 0; index--) {
                    if (tabItems.get(index).detachedTrailing) {
                        trailingItem = tabItems.remove(index);
                        break;
                    }
                }
                if (trailingItem != null) {
                    tabItems.removeIf((item) -> item.detachedTrailing);
                    tabItems.add(trailingItem);
                }
            }
            for (int index = 0; index < tabItems.size(); index++) {
                if (tabItems.get(index).id.equals(selectedId)) {
                    selectedTabIndex = index;
                    break;
                }
            }

            if (tabItems.isEmpty()) {
                tabbarVisible = false;
                if (tabbarContainer != null) {
                    tabbarContainer.setVisibility(View.GONE);
                }
                nativeTabbar.setVisibility(View.GONE);
                layoutChrome();
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            if (selectedTabIndex < 0 || selectedTabIndex >= tabItems.size()) {
                selectedTabIndex = 0;
            }

            if (tabbarMinimizeEnabled()) {
                startNavbarScrollObservation();
            } else {
                setTabbarMinimized(false, false);
            }
            applyTabbarBackground(centerTabIndex());
            renderTabbarItems(labelVisibilityMode, icons);
            layoutChrome();
            setTabbarChromeVisible(true, animated);
            updateInsetsAndNotify();
            call.resolve(insetsResult());
        });
    }

    @PluginMethod
    public void beginTransition(PluginCall call) {
        runOnUiThread(() -> {
            View webView = getBridge().getWebView();
            FrameLayout root = contentRoot();
            if (webView == null || root == null || webView.getWidth() <= 0 || webView.getHeight() <= 0) {
                call.reject("WebView unavailable");
                return;
            }

            activeTransitionId = call.getString("id", "transition-" + System.currentTimeMillis());
            activeTransitionDirection = call.getString("direction", "forward");
            Double duration = call.getDouble("duration");
            activeTransitionMs = duration == null ? defaultTransitionMs : Math.max(0, duration.intValue());
            RectF zoomSourceRect = "zoom".equals(activeTransitionDirection) ? transitionRect(call.getObject("sourceRect", null)) : null;
            activeZoomSourceFrame = zoomSourceRect == null ? null : rootFrame(zoomSourceRect, webView);
            Double cornerRadius = call.getDouble("cornerRadius");
            activeZoomCornerRadius = cornerRadius == null ? 0f : cornerRadius.floatValue();

            if (transitionSnapshot != null) {
                root.removeView(transitionSnapshot);
                restoreTransitionRootBackground();
            }

            int transitionSurface = transitionSurfaceColor(webView);
            prepareTransitionRootBackground(root, transitionSurface);
            Bitmap bitmap = Bitmap.createBitmap(webView.getWidth(), webView.getHeight(), Bitmap.Config.ARGB_8888);
            webView.draw(new Canvas(bitmap));
            if (zoomSourceRect != null) {
                Rect crop = bitmapCropRect(zoomSourceRect, bitmap);
                bitmap = Bitmap.createBitmap(bitmap, crop.left, crop.top, crop.width(), crop.height());
            }
            transitionSnapshot = new ImageView(getContext());
            transitionSnapshot.setImageBitmap(bitmap);
            transitionSnapshot.setBackgroundColor(transitionSurface);
            transitionSnapshot.setScaleType(ImageView.ScaleType.FIT_XY);
            FrameLayout.LayoutParams params =
                activeZoomSourceFrame == null
                    ? new FrameLayout.LayoutParams(webView.getWidth(), webView.getHeight())
                    : new FrameLayout.LayoutParams(Math.round(activeZoomSourceFrame.width()), Math.round(activeZoomSourceFrame.height()));
            params.leftMargin = activeZoomSourceFrame == null ? webView.getLeft() : Math.round(activeZoomSourceFrame.left);
            params.topMargin = activeZoomSourceFrame == null ? webView.getTop() : Math.round(activeZoomSourceFrame.top);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && activeZoomCornerRadius > 0) {
                transitionSnapshot.setClipToOutline(true);
                transitionSnapshot.setOutlineProvider(roundRectOutlineProvider(activeZoomCornerRadius));
            }
            root.addView(transitionSnapshot, params);
            webView.setAlpha(0.01f);
            bringChromeToFront();

            JSObject event = transitionEvent(activeTransitionId, activeTransitionDirection, activeTransitionMs);
            notifyListeners("transitionStart", event);
            call.resolve(event);
        });
    }

    @PluginMethod
    public void finishTransition(PluginCall call) {
        runOnUiThread(() -> {
            View webView = getBridge().getWebView();
            if (webView == null) {
                call.reject("WebView unavailable");
                return;
            }
            // A new route starts at the top; a stale offset would block the gesture.
            pullToRefresh.resetWebScroll();

            String transitionId = call.getString(
                "id",
                activeTransitionId == null ? "transition-" + System.currentTimeMillis() : activeTransitionId
            );
            String direction = call.getString("direction", activeTransitionDirection);
            Double duration = call.getDouble("duration");
            int durationMs = duration == null ? activeTransitionMs : Math.max(0, duration.intValue());
            float width = webView.getWidth();
            if ("zoom".equals(direction)) {
                RectF sourceRect = transitionRect(call.getObject("sourceRect", null));
                RectF targetRect = transitionRect(call.getObject("targetRect", null));
                Double cornerRadius = call.getDouble("cornerRadius");
                finishZoomTransition(
                    webView,
                    transitionSnapshot,
                    transitionId,
                    durationMs,
                    sourceRect == null ? null : rootFrame(sourceRect, webView),
                    targetRect == null ? null : rootFrame(targetRect, webView),
                    cornerRadius == null ? activeZoomCornerRadius : cornerRadius.floatValue(),
                    call
                );
                return;
            }
            float startTranslation;
            float snapshotEndTranslation;
            if ("back".equals(direction)) {
                startTranslation = -width * 0.3f;
                snapshotEndTranslation = width;
            } else if ("tab".equals(direction) || "root".equals(direction) || "none".equals(direction)) {
                startTranslation = 0;
                snapshotEndTranslation = 0;
            } else {
                startTranslation = width;
                snapshotEndTranslation = -width * 0.3f;
            }

            boolean stationaryTransition = isStationaryTransition(direction);
            webView.setTranslationX(startTranslation);
            webView.setAlpha(stationaryTransition ? 1f : 0.01f);
            View snapshot = transitionSnapshot;
            JSObject event = transitionEvent(transitionId, direction, durationMs);
            Runnable finish = () -> {
                FrameLayout root = contentRoot();
                if (root != null && transitionSnapshot != null) {
                    root.removeView(transitionSnapshot);
                }
                restoreTransitionRootBackground();
                transitionSnapshot = null;
                activeTransitionId = null;
                activeZoomSourceFrame = null;
                webView.setTranslationX(0);
                webView.setAlpha(1f);
                notifyListeners("transitionEnd", event);
                call.resolve(event);
            };

            if (durationMs == 0) {
                finish.run();
                return;
            }

            webView.animate().translationX(0).alpha(1f).setDuration(durationMs).start();
            if (snapshot != null) {
                snapshot
                    .animate()
                    .translationX(snapshotEndTranslation)
                    .alpha(stationaryTransition ? 0f : 0.75f)
                    .setDuration(durationMs)
                    .withEndAction(finish)
                    .start();
            } else {
                webView.postDelayed(finish, durationMs);
            }
        });
    }

    @PluginMethod
    public void getPluginVersion(PluginCall call) {
        JSObject ret = new JSObject();
        ret.put("version", implementation.getPluginVersion());
        call.resolve(ret);
    }

    private void finishZoomTransition(
        View webView,
        View snapshot,
        String transitionId,
        int durationMs,
        RectF sourceFrame,
        RectF targetFrame,
        float cornerRadius,
        PluginCall call
    ) {
        RectF startFrame = sourceFrame == null ? activeZoomSourceFrame : sourceFrame;
        if (startFrame == null) {
            startFrame = new RectF(webView.getLeft(), webView.getTop(), webView.getRight(), webView.getBottom());
        }
        JSObject event = transitionEvent(transitionId, "zoom", durationMs);
        Runnable finish = () -> {
            FrameLayout root = contentRoot();
            if (root != null && transitionSnapshot != null) {
                root.removeView(transitionSnapshot);
            }
            restoreTransitionRootBackground();
            transitionSnapshot = null;
            activeTransitionId = null;
            activeZoomSourceFrame = null;
            webView.setTranslationX(0);
            webView.setTranslationY(0);
            webView.setScaleX(1f);
            webView.setScaleY(1f);
            webView.setAlpha(1f);
            notifyListeners("transitionEnd", event);
            call.resolve(event);
        };

        if (durationMs == 0) {
            finish.run();
            return;
        }

        if (targetFrame != null && snapshot != null) {
            webView.setAlpha(0.01f);
            snapshot.setX(startFrame.left);
            snapshot.setY(startFrame.top);
            snapshot.setPivotX(0f);
            snapshot.setPivotY(0f);
            float scaleX = targetFrame.width() / Math.max(startFrame.width(), 1f);
            float scaleY = targetFrame.height() / Math.max(startFrame.height(), 1f);
            webView.animate().alpha(1f).setDuration(durationMs).start();
            snapshot
                .animate()
                .x(targetFrame.left)
                .y(targetFrame.top)
                .scaleX(scaleX)
                .scaleY(scaleY)
                .alpha(0f)
                .setDuration(durationMs)
                .withEndAction(finish)
                .start();
            return;
        }

        float fullWidth = Math.max(webView.getWidth(), 1f);
        float fullHeight = Math.max(webView.getHeight(), 1f);
        float fullCenterX = webView.getLeft() + fullWidth / 2f;
        float fullCenterY = webView.getTop() + fullHeight / 2f;
        webView.setPivotX(fullWidth / 2f);
        webView.setPivotY(fullHeight / 2f);
        webView.setTranslationX(startFrame.centerX() - fullCenterX);
        webView.setTranslationY(startFrame.centerY() - fullCenterY);
        webView.setScaleX(Math.max(startFrame.width() / fullWidth, 0.01f));
        webView.setScaleY(Math.max(startFrame.height() / fullHeight, 0.01f));
        webView.setAlpha(1f);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP && cornerRadius > 0) {
            webView.setClipToOutline(true);
            webView.setOutlineProvider(roundRectOutlineProvider(cornerRadius));
        }

        if (snapshot != null) {
            snapshot.setX(startFrame.left);
            snapshot.setY(startFrame.top);
            snapshot.setPivotX(0f);
            snapshot.setPivotY(0f);
            snapshot
                .animate()
                .x(webView.getLeft())
                .y(webView.getTop())
                .scaleX(fullWidth / Math.max(startFrame.width(), 1f))
                .scaleY(fullHeight / Math.max(startFrame.height(), 1f))
                .alpha(0f)
                .setDuration(durationMs)
                .start();
        }

        webView
            .animate()
            .translationX(0)
            .translationY(0)
            .scaleX(1f)
            .scaleY(1f)
            .alpha(1f)
            .setDuration(durationMs)
            .withEndAction(() -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    webView.setClipToOutline(false);
                    webView.setOutlineProvider(ViewOutlineProvider.BACKGROUND);
                }
                finish.run();
            })
            .start();
    }

    private void applyNavbarSegments(JSONArray rawGroups) {
        List<NavbarSegmentRows.Group> groups = new ArrayList<>();
        for (int groupIndex = 0; groupIndex < rawGroups.length(); groupIndex++) {
            JSONObject rawGroup = rawGroups.optJSONObject(groupIndex);
            String groupId = rawGroup == null ? null : rawGroup.optString("id", null);
            if (groupId == null) {
                continue;
            }
            JSONArray rawItems = rawGroup.optJSONArray("items");
            List<NavbarSegmentRows.Item> items = new ArrayList<>();
            for (int index = 0; rawItems != null && index < rawItems.length(); index++) {
                JSONObject rawItem = rawItems.optJSONObject(index);
                String id = rawItem == null ? null : rawItem.optString("id", null);
                if (id == null) {
                    continue;
                }
                JSONObject icon = rawItem.optJSONObject("icon");
                items.add(
                    new NavbarSegmentRows.Item(
                        id,
                        rawItem.optString("title", null),
                        rawItem.optString("accessibilityLabel", null),
                        rawItem.optBoolean("enabled", true),
                        icon == null ? "" : icon.toString(),
                        iconFrom(icon)
                    )
                );
            }
            if (!items.isEmpty()) {
                groups.add(
                    new NavbarSegmentRows.Group(groupId, items, rawGroup.optString("selectedId", null), rawGroup.optString("style", "auto"))
                );
            }
        }
        navbarSegments.apply(groups, tintColor, navbarForegroundColor);
        navbarSegments.setVisibility(groups.isEmpty() ? View.GONE : View.VISIBLE);
    }

    private void applyNavbarSearch(JSObject search, boolean large) {
        if (navbarSearchField == null) {
            return;
        }
        if (search == null || search.optBoolean("hidden", false)) {
            navbarSearchVisible = false;
            navbarSearchSuppliedText = null;
            navbarSearchField.setVisibility(View.GONE);
            return;
        }
        navbarSearchVisible = true;
        Boolean hidesWhenCollapsed = search.has("hidesWhenCollapsed")
            ? Boolean.valueOf(search.optBoolean("hidesWhenCollapsed", large))
            : null;
        navbarSearchHidesWhenCollapsed = NavbarSearchSupport.hidesWhenCollapsed(hidesWhenCollapsed, large);
        String placeholder = search.optString("placeholder", "Search");
        navbarSearchField.setHint(placeholder.isEmpty() ? "Search" : placeholder);
        navbarSearchField.setEnabled(search.optBoolean("enabled", true));
        navbarSearchField.setTextColor(navbarForegroundColor);
        navbarSearchField.setHintTextColor(withAlpha(navbarForegroundColor, 140));
        String text = search.optString("text", "");
        if (
            NavbarSearchSupport.shouldApplyText(
                navbarSearchField.hasFocus(),
                navbarSearchField.getText().toString(),
                text,
                navbarSearchSuppliedText
            )
        ) {
            navbarSearchApplying = true;
            navbarSearchField.setText(text);
            navbarSearchApplying = false;
        }
        navbarSearchSuppliedText = text;
        navbarSearchField.setVisibility(navbarSearchHeight() > 0 ? View.VISIBLE : View.GONE);
    }

    /** Height of the stacked search row, in device pixels. */
    private int navbarSearchHeight() {
        return dp(
            NavbarSearchSupport.rowHeightDp(navbarSearchVisible, navbarSearchHidesWhenCollapsed, navbarLarge && navbarSearchCollapsed)
        );
    }

    private int navbarAccessoryHeight() {
        return navbarSearchHeight() + navbarSegmentsHeight();
    }

    /** Height of the segment rows under the toolbar, in device pixels. */
    private int navbarSegmentsHeight() {
        if (navbarSegments == null || navbarSegments.getVisibility() != View.VISIBLE) {
            return 0;
        }
        return navbarSegments.rowCount() * dp(NavbarSegmentRows.ROW_HEIGHT_DP);
    }

    /** Index of the first left item whose icon renders on Android, or -1. */
    private int firstResolvableLeadingIconIndex(JSONArray rawItems, boolean rtl) {
        for (int index = 0; index < rawItems.length(); index++) {
            JSONObject rawItem = rawItems.optJSONObject(index);
            if (rawItem == null) {
                continue;
            }
            JSONObject descriptor = rawItem.optJSONObject("icon");
            if (descriptor != null && leadingIconFrom(descriptor, rtl) != null) {
                return index;
            }
        }
        return -1;
    }

    private static JSONArray withoutIndex(JSONArray rawItems, int skip) {
        JSONArray rest = new JSONArray();
        for (int index = 0; index < rawItems.length(); index++) {
            if (index != skip) {
                rest.put(rawItems.opt(index));
            }
        }
        return rest;
    }

    /** Last rendered leading icon, reused while its descriptor is unchanged so repeated setNavbar calls do not re-render it. */
    private String leadingIconKey;
    private Drawable leadingIcon;

    /**
     * Shows a left item in the toolbar's navigation slot. An SVG icon is rendered at its own width x height dp,
     * starts on the 16dp keyline, and the slot is at least 56dp wide. A tap sends the same `navbarItemTap`
     * event as iOS ({ id, title, placement: "left" }).
     */
    private void applyLeadingNavigationItem(Toolbar nativeToolbar, JSONObject rawItem) {
        String id = rawItem.optString("id", "leading");
        String title = rawItem.optString("title", "");
        JSONObject descriptor = rawItem.optJSONObject("icon");
        boolean rtl = nativeToolbar.getLayoutDirection() == View.LAYOUT_DIRECTION_RTL;
        String key = String.valueOf(descriptor) + "|" + rtl;
        Drawable icon = key.equals(leadingIconKey) ? leadingIcon : leadingIconFrom(descriptor, rtl);
        leadingIconKey = key;
        leadingIcon = icon;
        if (nativeToolbar.getNavigationIcon() != icon) {
            nativeToolbar.setNavigationIcon(icon);
        }
        nativeToolbar.setNavigationContentDescription(itemContentDescription(rawItem, id, title));
        boolean enabled = rawItem.optBoolean("enabled", true);
        nativeToolbar.setNavigationOnClickListener(
            enabled
                ? (v) -> {
                    JSObject event = new JSObject();
                    event.put("id", id);
                    event.put("title", title);
                    event.put("placement", "left");
                    notifyListeners("navbarItemTap", event);
                }
                : null
        );
    }

    private Drawable leadingIconFrom(JSONObject descriptor, boolean rtl) {
        Drawable base;
        String svg = svgFrom(descriptor);
        if (svg == null || svg.isEmpty()) {
            svg = inlineSvgFromAndroidIconResource(descriptor);
        }
        if (svg != null && !svg.isEmpty()) {
            float widthDp = (float) Math.max(1, descriptor.optDouble("width", 24));
            float heightDp = (float) Math.max(1, descriptor.optDouble("height", 24));
            base = SvgIconRenderer.render(getContext().getResources(), svg, widthDp, heightDp);
        } else {
            base = iconFrom(descriptor);
        }
        if (base == null) {
            return null;
        }
        int width = Math.max(1, base.getIntrinsicWidth());
        int start = dp(16);
        int end = Math.max(0, dp(56) - start - width);
        return new InsetDrawable(base, rtl ? end : start, 0, rtl ? start : end, 0);
    }

    private String itemContentDescription(JSONObject rawItem, String id, String title) {
        String accessibilityLabel = rawItem.optString("accessibilityLabel", "");
        if (accessibilityLabel.isEmpty()) {
            accessibilityLabel = title.isEmpty() ? id : title;
        }
        return accessibilityLabel;
    }

    private void addToolbarItems(Toolbar nativeToolbar, JSONArray rawItems, String placement) {
        for (int index = 0; index < rawItems.length(); index++) {
            JSONObject rawItem = rawItems.optJSONObject(index);
            if (rawItem == null) {
                continue;
            }
            int itemId = MENU_ITEM_BASE + menuActionIds.size();
            String id = rawItem.optString("id", "item-" + itemId);
            String title = rawItem.optString("title", "");
            MenuItem item = nativeToolbar.getMenu().add(Menu.NONE, itemId, index, title);
            item.setEnabled(rawItem.optBoolean("enabled", true));
            MenuItemCompat.setContentDescription(item, itemContentDescription(rawItem, id, title));
            Drawable icon = iconFrom(rawItem.optJSONObject("icon"));
            if (icon != null) {
                item.setIcon(icon);
            }
            item.setShowAsAction(MenuItem.SHOW_AS_ACTION_ALWAYS);
            menuActionIds.put(itemId, id);
            menuActionTitles.put(itemId, title);
            menuActionPlacements.put(itemId, placement);
        }
    }

    private RectF transitionRect(JSObject object) {
        if (object == null) {
            return null;
        }
        double width = object.optDouble("width", 0);
        double height = object.optDouble("height", 0);
        if (width <= 0 || height <= 0) {
            return null;
        }
        float x = (float) object.optDouble("x", 0);
        float y = (float) object.optDouble("y", 0);
        return new RectF(x, y, x + (float) width, y + (float) height);
    }

    private RectF rootFrame(RectF viewportRect, View webView) {
        return new RectF(
            webView.getLeft() + viewportRect.left,
            webView.getTop() + viewportRect.top,
            webView.getLeft() + viewportRect.right,
            webView.getTop() + viewportRect.bottom
        );
    }

    private Rect bitmapCropRect(RectF viewportRect, Bitmap bitmap) {
        int left = Math.max(0, Math.min(bitmap.getWidth() - 1, Math.round(viewportRect.left)));
        int top = Math.max(0, Math.min(bitmap.getHeight() - 1, Math.round(viewportRect.top)));
        int right = Math.max(left + 1, Math.min(bitmap.getWidth(), Math.round(viewportRect.right)));
        int bottom = Math.max(top + 1, Math.min(bitmap.getHeight(), Math.round(viewportRect.bottom)));
        return new Rect(left, top, right, bottom);
    }

    private ViewOutlineProvider roundRectOutlineProvider(float radius) {
        return new ViewOutlineProvider() {
            @Override
            public void getOutline(View view, Outline outline) {
                outline.setRoundRect(0, 0, view.getWidth(), view.getHeight(), radius);
            }
        };
    }

    private void applyTabbarContainerOutline() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP || tabbarContainer == null) {
            return;
        }

        if (tabbarStyle.isCurve()) {
            tabbarContainer.setClipToOutline(false);
            tabbarContainer.setOutlineProvider(ViewOutlineProvider.BACKGROUND);
            if (tabbarGlassSurface != null) {
                tabbarGlassSurface.setClipToOutline(false);
                tabbarGlassSurface.setOutlineProvider(ViewOutlineProvider.BACKGROUND);
            }
            return;
        }

        ViewOutlineProvider floatingOutlineProvider = floatingTabbarOutlineProvider();
        tabbarContainer.setClipToOutline(false);
        tabbarContainer.setOutlineProvider(floatingOutlineProvider);
        if (tabbarGlassSurface != null) {
            tabbarGlassSurface.setClipToOutline(true);
            tabbarGlassSurface.setOutlineProvider(floatingOutlineProvider);
        }
    }

    private ViewOutlineProvider floatingTabbarOutlineProvider() {
        return new ViewOutlineProvider() {
            @Override
            public void getOutline(View view, Outline outline) {
                int width = view.getWidth();
                int height = view.getHeight();
                if (width <= 0 || height <= 0 || tabbar == null) {
                    outline.setEmpty();
                    return;
                }

                Path path = tabbar.chromeBackgroundPath(width, height);
                if (TabbarChromeSupport.canApplyPathOutline()) {
                    outline.setPath(path);
                    return;
                }

                boolean hasDetachedTrailing = tabItems.stream().anyMatch((item) -> item.detachedTrailing);
                int trailingDiameter = Math.min(dp(tabbarStyle.height), height);
                int trailingGap = dp(10);
                int capsuleWidth = TabbarChromeSupport.floatingCapsuleWidth(
                    width,
                    trailingDiameter,
                    trailingGap,
                    hasDetachedTrailing
                );
                int capsuleLeft = hasDetachedTrailing
                    ? TabbarLayoutSupport.capsuleLeftForDetachedTrailing(trailingDiameter, trailingGap, tabbar.isLayoutRtl())
                    : 0;
                float radius = Math.min(dp(tabbarStyle.cornerRadius), height / 2f);
                outline.setRoundRect(capsuleLeft, 0, capsuleLeft + capsuleWidth, height, radius);
            }
        };
    }

    private Toolbar ensureToolbar() {
        if (toolbar != null) {
            return toolbar;
        }
        FrameLayout root = contentRoot();
        navbarContainer = new FrameLayout(getContext());
        navbarContainer.setElevation(dp(8));
        toolbar = new Toolbar(getContext());
        toolbar.setPopupTheme(androidx.appcompat.R.style.ThemeOverlay_AppCompat_Light);
        navbarGlassSurface = new View(getContext());
        navbarGlassSurface.setVisibility(View.GONE);

        toolbar.setOnMenuItemClickListener((item) -> {
            int itemId = item.getItemId();
            JSObject event = new JSObject();
            event.put("id", menuActionIds.get(itemId));
            event.put("title", menuActionTitles.get(itemId));
            event.put("placement", menuActionPlacements.get(itemId));
            notifyListeners("navbarItemTap", event);
            return true;
        });

        largeTitleView = new TextView(getContext());
        largeTitleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, NavbarLargeTitleSupport.LARGE_TITLE_TEXT_SP);
        largeTitleView.setTypeface(Typeface.create(Typeface.DEFAULT, Typeface.BOLD));
        largeTitleView.setSingleLine(true);
        largeTitleView.setEllipsize(TextUtils.TruncateAt.END);
        largeTitleView.setGravity(Gravity.BOTTOM | Gravity.START);
        largeTitleView.setPaddingRelative(dp(16), 0, dp(16), dp(NavbarLargeTitleSupport.LARGE_TITLE_BOTTOM_PADDING_DP));
        largeTitleView.setAlpha(0f);
        // The toolbar keeps the title for screen readers; the large copy is visual only.
        largeTitleView.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);

        navbarSearchField = new EditText(getContext());
        navbarSearchField.setSingleLine(true);
        navbarSearchField.setImeOptions(EditorInfo.IME_ACTION_SEARCH);
        navbarSearchField.setInputType(InputType.TYPE_CLASS_TEXT);
        navbarSearchField.setHint("Search");
        navbarSearchField.setVisibility(View.GONE);
        GradientDrawable searchBackground = new GradientDrawable();
        searchBackground.setCornerRadius(dp(12));
        searchBackground.setColor(Color.argb(36, 120, 120, 128));
        navbarSearchField.setBackground(searchBackground);
        navbarSearchField.setPadding(dp(14), 0, dp(14), 0);
        navbarSearchField.setOnEditorActionListener((view, actionId, event) -> {
            if (actionId != EditorInfo.IME_ACTION_SEARCH) {
                return false;
            }
            JSObject payload = new JSObject();
            payload.put("text", view.getText() == null ? "" : view.getText().toString());
            payload.put("reason", "submit");
            notifyListeners("navbarSearch", payload);
            return true;
        });
        navbarSearchField.addTextChangedListener(
            new TextWatcher() {
                @Override
                public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

                @Override
                public void onTextChanged(CharSequence s, int start, int before, int count) {}

                @Override
                public void afterTextChanged(Editable s) {
                    if (navbarSearchApplying) {
                        return;
                    }
                    JSObject payload = new JSObject();
                    payload.put("text", s == null ? "" : s.toString());
                    payload.put("reason", "input");
                    notifyListeners("navbarSearch", payload);
                }
            }
        );

        navbarSegments = new NavbarSegmentRows(getContext());
        navbarSegments.setVisibility(View.GONE);
        navbarSegments.setOnSelectListener((groupId, id, index) -> {
            JSObject event = new JSObject();
            event.put("groupId", groupId);
            event.put("id", id);
            event.put("index", index);
            notifyListeners("navbarSegmentSelect", event);
        });

        navbarContainer.addView(navbarGlassSurface);
        navbarContainer.addView(toolbar);
        navbarContainer.addView(largeTitleView);
        navbarContainer.addView(navbarSearchField);
        navbarContainer.addView(navbarSegments);
        if (root != null) {
            root.addView(navbarContainer);
        } else {
            getActivity().addContentView(
                navbarContainer,
                new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(DEFAULT_NAVBAR_DP))
            );
        }
        return toolbar;
    }

    private NativeTabbarLayout ensureTabbar() {
        if (tabbar != null) {
            return tabbar;
        }
        FrameLayout root = contentRoot();
        tabbarBackdrop = new View(getContext());
        tabbarBackdrop.setBackgroundColor(resolvedTabbarSurfaceColor());
        tabbarContainer = new FrameLayout(getContext());
        tabbarContainer.setClipChildren(false);
        tabbarContainer.setClipToPadding(false);
        tabbarContainer.setElevation(dp(12));
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            tabbarContainer.setOutlineAmbientShadowColor(0x33000000);
            tabbarContainer.setOutlineSpotShadowColor(0x66000000);
        }

        tabbarGlassSurface = new View(getContext());
        tabbarGlassSurface.setVisibility(View.GONE);
        tabbar = new NativeTabbarLayout(getContext());
        tabbar.setClipChildren(false);
        tabbar.setClipToPadding(false);
        tabbar.setBackgroundColor(Color.TRANSPARENT);
        tabbar.setDragListener(
            new NativeTabbarLayout.DragListener() {
                @Override
                public void onDragStart() {
                    setTabbarMinimized(false, true);
                }

                @Override
                public void onDragHover(int index) {
                    tintTabButtons(index);
                }

                @Override
                public boolean canSelect(int index) {
                    return index >= 0 && index < tabItems.size() && tabItems.get(index).enabled;
                }

                @Override
                public void onDragSelect(int index) {
                    selectTab(index);
                }
            }
        );
        tabbarContainer.addView(tabbarGlassSurface);
        tabbarContainer.addView(
            tabbar,
            new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        );
        if (root != null) {
            root.addView(tabbarBackdrop);
            root.addView(tabbarContainer);
        } else {
            getActivity().addContentView(
                tabbarBackdrop,
                new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, Gravity.BOTTOM)
            );
            getActivity().addContentView(
                tabbarContainer,
                new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(DEFAULT_TABBAR_DP))
            );
        }
        applyTabbarContainerOutline();
        return tabbar;
    }

    private void renderTabbarItems(String labelVisibilityMode, boolean icons) {
        if (tabbar == null) {
            return;
        }
        tabbar.removeAllViews();
        tabbarLabelVisibilityMode = labelVisibilityMode;
        tabbarIconsVisible = icons;
        tabbar.setSelectionState(
            selectedTabIndex,
            !tabbarStyle.isCurve() && !tabbarStyle.isSidebar() && tabbarDragToSelect,
            !tabbarDisableIndicator,
            TabbarChromeSupport.resolveSelectedIndicatorColor(tabbarIndicatorColor, tintColor)
        );
        int centerIndex = centerTabIndex();
        applyTabbarBackground(centerIndex);
        for (int index = 0; index < tabItems.size(); index++) {
            final int itemIndex = index;
            NativeTabItem item = tabItems.get(index);
            boolean selected = itemIndex == selectedTabIndex;
            boolean detachedTrailing = item.detachedTrailing && !tabbarStyle.isCurve() && !tabbarStyle.isSidebar();
            boolean showLabel = detachedTrailing
                ? !icons && shouldShowTabLabel(labelVisibilityMode, selected)
                : shouldShowTabLabel(labelVisibilityMode, selected);
            FrameLayout button = makeTabButton(item, selected, showLabel, icons, itemIndex == centerIndex);
            if (detachedTrailing) {
                button.setTag("detachedTrailing");
            }
            button.setSelected(selected);
            button.setEnabled(item.enabled);
            button.setAlpha(item.enabled ? 1f : 0.38f);
            button.setOnClickListener((view) -> {
                if (!item.enabled) {
                    return;
                }
                setTabbarMinimized(false, true);
                if (!tabbarStyle.isCurve() && !tabbarStyle.isSidebar() && !detachedTrailing) {
                    tabbar.slideIndicator(selectedTabIndex, itemIndex);
                }
                selectTab(itemIndex);
            });
            tabbar.addView(button, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        }
    }

    private void selectTab(int index) {
        if (tabbar == null || index < 0 || index >= tabItems.size()) {
            return;
        }
        boolean changed = index != selectedTabIndex;
        selectedTabIndex = index;
        renderTabbarItems(tabbarLabelVisibilityMode, tabbarIconsVisible);
        if (!changed) {
            return;
        }
        NativeTabItem item = tabItems.get(index);
        JSObject event = new JSObject();
        event.put("id", item.id);
        event.put("index", item.sourceIndex);
        event.put("title", item.title);
        notifyListeners("tabSelect", event);
    }

    /** While dragging, the tab under the finger lights up instead of the selected one. */
    private void tintTabButtons(int highlightedIndex) {
        if (tabbar == null) {
            return;
        }
        for (int index = 0; index < tabbar.getChildCount(); index++) {
            View child = tabbar.getChildAt(index);
            if (!(child instanceof TabButton) || index >= tabItems.size() || "detachedTrailing".equals(child.getTag())) {
                continue;
            }
            TabButton button = (TabButton) child;
            int color = index == highlightedIndex && tabItems.get(index).enabled ? tintColor : inactiveTintColor;
            if (button.icon != null) {
                button.icon.setColorFilter(color);
            }
            if (button.label != null) {
                button.label.setTextColor(color);
            }
        }
    }

    private boolean tabbarMinimizeEnabled() {
        return tabbarMinimizeOnScroll && !tabbarStyle.isCurve() && !tabbarStyle.isSidebar() && tabbarIconsVisible;
    }

    private void handleTabbarMinimizeScroll(float offsetY, float deltaY) {
        if (tabbar != null && tabbar.isDragging()) {
            return;
        }
        NavbarScrollSupport.ScrollAction action = NavbarScrollSupport.scrollAction(
            NavbarScrollSupport.ScrollBehavior.BOTH,
            offsetY,
            deltaY,
            navbarScrollThreshold,
            tabbarMinimized
        );
        if (action == NavbarScrollSupport.ScrollAction.HIDE) {
            setTabbarMinimized(true, true);
        } else if (action == NavbarScrollSupport.ScrollAction.REVEAL) {
            setTabbarMinimized(false, true);
        }
    }

    private void setTabbarMinimized(boolean minimized, boolean animated) {
        if (minimized && !tabbarMinimizeEnabled()) {
            return;
        }
        float target = minimized ? 1f : 0f;
        if (tabbarMinimized == minimized && (tabbarMinimizeAnimator != null || tabbarMinimizeProgress == target)) {
            return;
        }
        tabbarMinimized = minimized;
        if (tabbarMinimizeAnimator != null) {
            tabbarMinimizeAnimator.cancel();
            tabbarMinimizeAnimator = null;
        }
        if (!animated || tabbarContainer == null || tabbarContainer.getVisibility() != View.VISIBLE) {
            applyTabbarMinimizeProgress(target);
            return;
        }
        ValueAnimator animator = ValueAnimator.ofFloat(tabbarMinimizeProgress, target);
        animator.setDuration(TABBAR_MINIMIZE_ANIMATION_MS);
        animator.setInterpolator(new PathInterpolator(0.2f, 0f, 0f, 1f));
        animator.addUpdateListener((animation) -> applyTabbarMinimizeProgress((float) animation.getAnimatedValue()));
        animator.addListener(
            new AnimatorListenerAdapter() {
                @Override
                public void onAnimationEnd(Animator animation) {
                    if (tabbarMinimizeAnimator == animation) {
                        tabbarMinimizeAnimator = null;
                    }
                }
            }
        );
        tabbarMinimizeAnimator = animator;
        animator.start();
    }

    /** Revolut-style minimize: every icon stays, labels fold away and the capsule shrinks in both dimensions. */
    private void applyTabbarMinimizeProgress(float progress) {
        tabbarMinimizeProgress = Math.max(0f, Math.min(1f, progress));
        if (tabbar != null) {
            for (int index = 0; index < tabbar.getChildCount(); index++) {
                View child = tabbar.getChildAt(index);
                if (child instanceof TabButton) {
                    applyTabButtonMinimize((TabButton) child);
                }
            }
        }
        layoutTabbarContainer();
    }

    private void applyTabButtonMinimize(TabButton button) {
        float progress = tabbarMinimizeProgress;
        if (button.labelClip != null) {
            int height = Math.round(dp(TAB_LABEL_HEIGHT_DP) * (1f - progress));
            ViewGroup.LayoutParams params = button.labelClip.getLayoutParams();
            if (params != null && params.height != height) {
                params.height = height;
                button.labelClip.setLayoutParams(params);
            }
            button.labelClip.setAlpha(Math.max(0f, 1f - progress / 0.4f));
        }
        if (button.icon != null && button.labelClip != null) {
            ViewGroup.LayoutParams params = button.icon.getLayoutParams();
            if (params instanceof ViewGroup.MarginLayoutParams) {
                int margin = Math.round(dp(TAB_ICON_LABEL_GAP_DP) * (1f - progress));
                ViewGroup.MarginLayoutParams marginParams = (ViewGroup.MarginLayoutParams) params;
                if (marginParams.bottomMargin != margin) {
                    marginParams.bottomMargin = margin;
                    button.icon.setLayoutParams(marginParams);
                }
            }
        }
    }

    private boolean shouldShowTabLabel(String mode, boolean selected) {
        if ("unlabeled".equals(mode)) {
            return false;
        }
        if ("selected".equals(mode)) {
            return selected;
        }
        return true;
    }

    private FrameLayout makeTabButton(NativeTabItem item, boolean selected, boolean showLabel, boolean icons, boolean center) {
        TabButton button = new TabButton(getContext());
        button.setClipChildren(false);
        button.setClipToPadding(false);
        button.setForeground(selectableItemBackground());
        if (center) {
            GradientDrawable centerBackground = new GradientDrawable();
            centerBackground.setShape(GradientDrawable.OVAL);
            centerBackground.setColor(tabbarStyle.centerButtonColor);
            View centerFill = new View(getContext());
            centerFill.setBackground(centerBackground);
            int centerFillDiameter = dp(Math.max(tabbarStyle.centerButtonDiameter - 14, 44));
            button.addView(centerFill, new FrameLayout.LayoutParams(centerFillDiameter, centerFillDiameter, Gravity.CENTER));
        }

        Drawable currentIcon = selected && item.selectedIcon != null ? item.selectedIcon : item.icon;
        boolean labelVisible = center ? showLabel && (currentIcon == null || !icons) : showLabel;
        boolean iconVisible = icons && currentIcon != null;
        // Measured with the bold selected style for every tab so the slots don't shift when the selection changes.
        int contentWidth = indicatorContentWidth(item.title, labelVisible, iconVisible);
        button.preferredWidth = contentWidth + dp(INDICATOR_HORIZONTAL_PADDING_DP + INDICATOR_SLOT_INSET_DP) * 2;

        if (!center && selected && !tabbarDisableIndicator) {
            GradientDrawable selectedBackground = new GradientDrawable();
            selectedBackground.setShape(GradientDrawable.RECTANGLE);
            selectedBackground.setColor(TabbarChromeSupport.resolveSelectedIndicatorColor(tabbarIndicatorColor, tintColor));
            TabIndicatorView indicator = new TabIndicatorView(
                getContext(),
                contentWidth,
                indicatorContentHeight(labelVisible, iconVisible),
                !tabbarStyle.isCurve()
            );
            indicator.setBackground(selectedBackground);
            if (tabbar != null && tabbar.isIndicatorOverlayActive()) {
                // The tabbar is drawing the sliding capsule; this one appears when it lands.
                indicator.setVisibility(View.INVISIBLE);
            }
            button.indicator = indicator;
            button.addView(
                indicator,
                new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER)
            );
        }

        LinearLayout content = new LinearLayout(getContext());
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        content.setPadding(dp(TAB_CONTENT_PADDING_DP), dp(TAB_CONTENT_PADDING_DP), dp(TAB_CONTENT_PADDING_DP), dp(TAB_CONTENT_PADDING_DP));
        button.addView(content, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        int itemColor = center ? tabbarStyle.centerButtonIconColor : (selected ? tintColor : inactiveTintColor);
        if (iconVisible) {
            Drawable icon = currentIcon.mutate();
            icon.setTint(itemColor);
            ImageView image = new ImageView(getContext());
            image.setImageDrawable(icon);
            image.setColorFilter(itemColor);
            int imageSize = center ? dp(32) : dp(24);
            LinearLayout.LayoutParams imageParams = new LinearLayout.LayoutParams(imageSize, imageSize);
            imageParams.bottomMargin = labelVisible ? dp(TAB_ICON_LABEL_GAP_DP) : 0;
            content.addView(image, imageParams);
            button.icon = image;
        }

        if (labelVisible) {
            TextView label = new TextView(getContext());
            label.setText(item.title);
            label.setTextColor(itemColor);
            label.setTextSize(TAB_LABEL_TEXT_SP);
            label.setTypeface(Typeface.DEFAULT, selected ? Typeface.BOLD : Typeface.NORMAL);
            label.setGravity(Gravity.CENTER);
            // maxLines rather than singleLine: autosize is ignored on a single-line (horizontally scrolling) TextView.
            label.setMaxLines(1);
            // Shrink long titles to fit the tab instead of cutting them off.
            TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(label, 9, TAB_LABEL_TEXT_SP, 1, TypedValue.COMPLEX_UNIT_SP);
            button.label = label;
            if (iconVisible && !center) {
                // The label sits in a clip so minimize can fold it away without autosizing the text.
                FrameLayout labelClip = new FrameLayout(getContext());
                labelClip.addView(
                    label,
                    new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(TAB_LABEL_HEIGHT_DP), Gravity.TOP)
                );
                content.addView(labelClip, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(TAB_LABEL_HEIGHT_DP)));
                button.labelClip = labelClip;
            } else {
                content.addView(label, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(TAB_LABEL_HEIGHT_DP)));
            }
        }

        if (item.badge != null && !item.badge.isEmpty() && !"0".equals(item.badge)) {
            TextView badge = new TextView(getContext());
            badge.setText(item.badge);
            badge.setTextColor(badgeTextColor);
            badge.setTextSize(11);
            badge.setTypeface(Typeface.DEFAULT_BOLD);
            badge.setGravity(Gravity.CENTER);
            GradientDrawable badgeBackground = new GradientDrawable();
            badgeBackground.setColor(badgeBackgroundColor);
            badgeBackground.setCornerRadius(dp(9));
            badge.setBackground(badgeBackground);
            int badgeWidth = Math.max(dp(18), item.badge.length() * dp(7) + dp(10));
            FrameLayout.LayoutParams badgeParams = new FrameLayout.LayoutParams(
                badgeWidth,
                dp(18),
                Gravity.TOP | Gravity.CENTER_HORIZONTAL
            );
            badgeParams.topMargin = center ? 0 : dp(4);
            badge.setTranslationX(center ? dp(18) : dp(16));
            button.addView(badge, badgeParams);
        }

        button.setContentDescription(item.title);
        applyTabButtonMinimize(button);
        return button;
    }

    /** Width of the selected item's icon or label (whichever is wider), before the indicator padding. */
    private int indicatorContentWidth(String title, boolean labelVisible, boolean iconVisible) {
        int width = iconVisible ? dp(24) : 0;
        if (labelVisible && title != null) {
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            paint.setTypeface(Typeface.DEFAULT_BOLD);
            paint.setTextSize(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, TAB_LABEL_TEXT_SP, getContext().getResources().getDisplayMetrics()));
            width = Math.max(width, (int) Math.ceil(paint.measureText(title)));
        }
        return width;
    }

    private int indicatorContentHeight(boolean labelVisible, boolean iconVisible) {
        int height = 0;
        if (iconVisible) {
            height += dp(24);
        }
        if (labelVisible) {
            height += dp(TAB_LABEL_HEIGHT_DP) + (iconVisible ? dp(TAB_ICON_LABEL_GAP_DP) : 0);
        }
        return height;
    }

    /** Tab item that reports how wide it wants to be, so the tabbar can size slots to their content. */
    private static final class TabButton extends FrameLayout {

        int preferredWidth = 0;
        ImageView icon;
        TextView label;
        View labelClip;
        View indicator;

        TabButton(Context context) {
            super(context);
        }
    }

    /**
     * Selected-tab capsule. On the floating bar it fills the tab slot with an even inset, like the iOS 26 tab bar;
     * otherwise it wraps the item's icon and label with padding, kept inside its tab slot.
     */
    private static final class TabIndicatorView extends View {

        private final int contentWidth;
        private final int contentHeight;
        private final boolean fillSlot;

        TabIndicatorView(Context context, int contentWidth, int contentHeight, boolean fillSlot) {
            super(context);
            this.contentWidth = contentWidth;
            this.contentHeight = contentHeight;
            this.fillSlot = fillSlot;
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int slotWidth = MeasureSpec.getSize(widthMeasureSpec);
            int slotHeight = MeasureSpec.getSize(heightMeasureSpec);
            if (fillSlot && slotWidth > 0 && slotHeight > 0) {
                int inset = dp(FLOATING_INDICATOR_INSET_DP);
                setMeasuredSize(Math.max(0, slotWidth - inset * 2), Math.max(0, slotHeight - inset * 2));
                return;
            }
            int height = contentHeight + dp(INDICATOR_VERTICAL_PADDING_DP) * 2;
            if (slotHeight > 0) {
                height = Math.min(height, slotHeight);
            }
            int width = Math.max(height, contentWidth + dp(INDICATOR_HORIZONTAL_PADDING_DP) * 2);
            if (slotWidth > 0) {
                width = Math.min(width, slotWidth - dp(INDICATOR_SLOT_INSET_DP) * 2);
            }
            setMeasuredSize(width, height);
        }

        private void setMeasuredSize(int width, int height) {
            setMeasuredDimension(width, height);
            Drawable background = getBackground();
            if (background instanceof GradientDrawable) {
                ((GradientDrawable) background).setCornerRadius(height / 2f);
            }
        }

        private int dp(int value) {
            return Math.round(value * getResources().getDisplayMetrics().density);
        }
    }

    private Drawable iconFrom(JSONObject descriptor) {
        if (descriptor == null) {
            return null;
        }
        String svg = svgFrom(descriptor);
        if (svg != null && !svg.isEmpty()) {
            return SvgIconRenderer.render(getContext().getResources(), svg, iconSizeDp(descriptor));
        }
        JSONObject android = descriptor.optJSONObject("android");
        String resource = android == null ? null : android.optString("resource", null);
        if (resource == null || resource.isEmpty()) {
            resource = android == null ? null : android.optString("image", null);
        }
        if (resource == null || resource.isEmpty()) {
            resource = descriptor.optString("src", null);
        }
        String inlineSvg = inlineSvgFrom(resource);
        if (inlineSvg != null) {
            return SvgIconRenderer.render(getContext().getResources(), inlineSvg, iconSizeDp(descriptor));
        }
        if (resource == null || resource.isEmpty()) {
            return null;
        }
        int id = getContext().getResources().getIdentifier(resource, "drawable", getContext().getPackageName());
        if (id == 0) {
            id = getContext().getResources().getIdentifier(resource, "mipmap", getContext().getPackageName());
        }
        if (id == 0) {
            id = getContext().getResources().getIdentifier(resource, "drawable", "android");
        }
        return id == 0 ? null : AppCompatResources.getDrawable(getContext(), id);
    }

    private String svgFrom(JSONObject descriptor) {
        JSONObject android = descriptor.optJSONObject("android");
        if (android != null) {
            String svg = android.optString("svg", null);
            if (svg != null && !svg.isEmpty()) {
                return svg;
            }
        }
        String svg = descriptor.optString("svg", null);
        if (svg != null && !svg.isEmpty()) {
            return svg;
        }
        return inlineSvgFrom(descriptor.optString("src", null));
    }

    private String inlineSvgFromAndroidIconResource(JSONObject descriptor) {
        JSONObject android = descriptor.optJSONObject("android");
        String resource = android == null ? null : android.optString("resource", null);
        if (resource == null || resource.isEmpty()) {
            resource = android == null ? null : android.optString("image", null);
        }
        return inlineSvgFrom(resource);
    }

    private String inlineSvgFrom(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.startsWith("<svg")) {
            return trimmed;
        }
        String lower = trimmed.toLowerCase();
        if (!lower.startsWith("data:image/svg+xml")) {
            return null;
        }
        int comma = trimmed.indexOf(',');
        if (comma < 0) {
            return null;
        }
        String meta = trimmed.substring(0, comma);
        String payload = trimmed.substring(comma + 1);
        try {
            if (meta.contains(";base64")) {
                byte[] decoded = android.util.Base64.decode(payload, android.util.Base64.DEFAULT);
                return new String(decoded, "UTF-8");
            }
            return URLDecoder.decode(payload, "UTF-8");
        } catch (Exception ignored) {
            return null;
        }
    }

    private int iconSizeDp(JSONObject descriptor) {
        double width = descriptor.optDouble("width", 24);
        return (int) Math.max(1, Math.round(width));
    }

    private static String attr(XmlPullParser parser, String name) {
        return parser.getAttributeValue(null, name);
    }

    private static Float length(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        Matcher matcher = SvgIconRenderer.NUMBER_PATTERN.matcher(value.trim());
        return matcher.find() ? Float.parseFloat(matcher.group()) : null;
    }

    private static final class SvgStyle {

        boolean fill = true;
        boolean stroke = false;
        float strokeWidth = 2f;
        Paint.Cap lineCap = Paint.Cap.BUTT;
        Paint.Join lineJoin = Paint.Join.MITER;
        int alpha = 255;

        SvgStyle copy() {
            SvgStyle copy = new SvgStyle();
            copy.fill = fill;
            copy.stroke = stroke;
            copy.strokeWidth = strokeWidth;
            copy.lineCap = lineCap;
            copy.lineJoin = lineJoin;
            copy.alpha = alpha;
            return copy;
        }

        void apply(XmlPullParser parser) {
            String fillValue = attr(parser, "fill");
            if (fillValue != null) {
                fill = !"none".equalsIgnoreCase(fillValue);
            }
            String strokeValue = attr(parser, "stroke");
            if (strokeValue != null) {
                stroke = !"none".equalsIgnoreCase(strokeValue);
            }
            Float width = length(attr(parser, "stroke-width"));
            if (width != null) {
                strokeWidth = width;
            }
            Float opacity = length(attr(parser, "opacity"));
            if (opacity != null) {
                alpha = Math.max(0, Math.min(255, Math.round(opacity * 255)));
            }
            String cap = attr(parser, "stroke-linecap");
            if ("round".equalsIgnoreCase(cap)) {
                lineCap = Paint.Cap.ROUND;
            } else if ("square".equalsIgnoreCase(cap)) {
                lineCap = Paint.Cap.SQUARE;
            } else if (cap != null) {
                lineCap = Paint.Cap.BUTT;
            }
            String join = attr(parser, "stroke-linejoin");
            if ("round".equalsIgnoreCase(join)) {
                lineJoin = Paint.Join.ROUND;
            } else if ("bevel".equalsIgnoreCase(join)) {
                lineJoin = Paint.Join.BEVEL;
            } else if (join != null) {
                lineJoin = Paint.Join.MITER;
            }
        }
    }

    private static final class NativeTabItem {

        final String id;
        final String title;
        final Drawable icon;
        final Drawable selectedIcon;
        final String badge;
        final boolean enabled;
        final boolean detachedTrailing;
        final int sourceIndex;

        NativeTabItem(
            String id,
            String title,
            Drawable icon,
            Drawable selectedIcon,
            String badge,
            boolean enabled,
            boolean detachedTrailing,
            int sourceIndex
        ) {
            this.id = id;
            this.title = title;
            this.icon = icon;
            this.selectedIcon = selectedIcon;
            this.badge = badge;
            this.enabled = enabled;
            this.detachedTrailing = detachedTrailing;
            this.sourceIndex = sourceIndex;
        }
    }

    private static final class TabbarStyle {

        final String shape;
        final int height;
        final int horizontalMargin;
        final int maxWidth;
        final int bottomGap;
        final int cornerRadius;
        final String centerItemId;
        final int centerButtonDiameter;
        final int centerButtonLift;
        final int centerButtonColor;
        final int centerButtonIconColor;
        final String alignment;
        final String placement;

        TabbarStyle(
            String shape,
            int height,
            int horizontalMargin,
            int maxWidth,
            int bottomGap,
            int cornerRadius,
            String centerItemId,
            int centerButtonDiameter,
            int centerButtonLift,
            int centerButtonColor,
            int centerButtonIconColor,
            String alignment,
            String placement
        ) {
            this.shape = shape;
            this.height = height;
            this.horizontalMargin = horizontalMargin;
            this.maxWidth = maxWidth;
            this.bottomGap = bottomGap;
            this.cornerRadius = cornerRadius;
            this.centerItemId = centerItemId;
            this.centerButtonDiameter = centerButtonDiameter;
            this.centerButtonLift = centerButtonLift;
            this.centerButtonColor = centerButtonColor;
            this.centerButtonIconColor = centerButtonIconColor;
            this.alignment = alignment;
            this.placement = placement;
        }

        static TabbarStyle defaults(int tintColor) {
            return new TabbarStyle("floating", 64, 24, 430, 10, 32, null, 56, 28, tintColor, Color.WHITE, "center", "auto");
        }

        boolean isCurve() {
            return "curve".equals(shape);
        }

        boolean isSidebar() {
            return !isCurve() && "sidebar".equals(placement);
        }

        int barTop() {
            return isCurve() ? centerButtonLift : 0;
        }

        int totalHeight() {
            return height + barTop();
        }
    }

    private static final class NativeTabbarLayout extends FrameLayout {

        /** Receives drag-to-select events from the floating tabbar. */
        interface DragListener {
            void onDragStart();

            void onDragHover(int index);

            boolean canSelect(int index);

            void onDragSelect(int index);
        }

        private final Paint backgroundPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Paint indicatorPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final RectF indicatorRect = new RectF();
        private final int touchSlop;
        private TabbarStyle style = TabbarStyle.defaults(Color.rgb(0, 122, 255));
        private int backgroundColor = DEFAULT_TABBAR_BACKGROUND_COLOR;
        private int centerIndex = -1;
        private DragListener dragListener;
        private int selectedIndex = -1;
        private boolean dragEnabled = true;
        private boolean indicatorEnabled = true;
        // Slot geometry of the draggable tabs, refreshed on every layout so the sliding capsule
        // keeps working while the tabs are re-rendered underneath it.
        private float[] slotCenters = new float[0];
        private float[] slotWidths = new float[0];
        private boolean overlayActive = false;
        private float overlayPosition = 0f;
        private ValueAnimator overlayAnimator;
        private boolean tracking = false;
        private boolean dragging = false;
        private float downX = 0f;
        private float downY = 0f;
        private int hoverIndex = -1;
        private boolean layoutRtl = false;

        NativeTabbarLayout(Context context) {
            super(context);
            setWillNotDraw(false);
            touchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
        }

        void applyLayoutDirection(String layoutDirection) {
            layoutRtl = TabbarLayoutSupport.isRtlLayoutDirection(layoutDirection);
            int direction = TabbarLayoutSupport.viewLayoutDirectionForTabbarOption(layoutDirection);
            setLayoutDirection(direction);
            for (int index = 0; index < getChildCount(); index++) {
                getChildAt(index).setLayoutDirection(direction);
            }
        }

        boolean isLayoutRtl() {
            return layoutRtl;
        }

        void setDragListener(DragListener listener) {
            this.dragListener = listener;
        }

        void setSelectionState(int selectedIndex, boolean dragEnabled, boolean indicatorEnabled, int indicatorColor) {
            this.selectedIndex = selectedIndex;
            this.dragEnabled = dragEnabled;
            this.indicatorEnabled = indicatorEnabled;
            indicatorPaint.setColor(indicatorColor);
            if (!dragEnabled && dragging) {
                cancelDrag();
            }
        }

        boolean isDragging() {
            return dragging;
        }

        boolean isIndicatorOverlayActive() {
            return overlayActive;
        }

        /** Slides the capsule from one tab to another, like the iOS tab bar does on tap. */
        void slideIndicator(int from, int to) {
            if (style.isCurve() || dragging || from == to || from < 0 || to < 0 || to >= slotCenters.length || from >= slotCenters.length) {
                return;
            }
            float start = overlayActive ? overlayPosition : from;
            showOverlay(start);
            animateOverlay(start, to);
        }

        private void showOverlay(float position) {
            if (overlayAnimator != null) {
                overlayAnimator.cancel();
                overlayAnimator = null;
            }
            overlayActive = true;
            overlayPosition = position;
            setChildIndicatorsVisible(false);
            invalidate();
        }

        private void animateOverlay(float from, int to) {
            ValueAnimator animator = ValueAnimator.ofFloat(from, to);
            animator.setDuration(TAB_INDICATOR_SLIDE_MS);
            animator.setInterpolator(new PathInterpolator(0.2f, 0f, 0f, 1f));
            animator.addUpdateListener((animation) -> {
                overlayPosition = (float) animation.getAnimatedValue();
                invalidate();
            });
            animator.addListener(
                new AnimatorListenerAdapter() {
                    private boolean cancelled = false;

                    @Override
                    public void onAnimationCancel(Animator animation) {
                        cancelled = true;
                    }

                    @Override
                    public void onAnimationEnd(Animator animation) {
                        if (cancelled || overlayAnimator != animation) {
                            return;
                        }
                        overlayAnimator = null;
                        overlayActive = false;
                        setChildIndicatorsVisible(true);
                        invalidate();
                    }
                }
            );
            overlayAnimator = animator;
            animator.start();
        }

        private void setChildIndicatorsVisible(boolean visible) {
            for (int index = 0; index < getChildCount(); index++) {
                View child = getChildAt(index);
                if (child instanceof TabButton && ((TabButton) child).indicator != null) {
                    ((TabButton) child).indicator.setVisibility(visible ? View.VISIBLE : View.INVISIBLE);
                }
            }
        }

        private boolean canDrag() {
            return dragEnabled && dragListener != null && !style.isCurve() && slotCenters.length > 1 && isEnabled();
        }

        private boolean inDragRange(float x) {
            return TabbarLayoutSupport.dragRangeContains(x, slotCenters, slotWidths);
        }

        /** Fractional tab position under {@code x}: 1.5 is halfway between the second and third tab. */
        private float positionAt(float x) {
            return TabbarLayoutSupport.dragPositionAt(x, slotCenters, layoutRtl);
        }

        @Override
        public boolean onInterceptTouchEvent(MotionEvent event) {
            if (!canDrag()) {
                return false;
            }
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    downX = event.getX();
                    downY = event.getY();
                    tracking = inDragRange(downX);
                    dragging = false;
                    return false;
                case MotionEvent.ACTION_MOVE:
                    if (!dragging && shouldStartDrag(event)) {
                        startDrag(event.getX());
                    }
                    return dragging;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    tracking = false;
                    return false;
                default:
                    return false;
            }
        }

        @Override
        public boolean onTouchEvent(MotionEvent event) {
            if (!canDrag() && !dragging) {
                return super.onTouchEvent(event);
            }
            switch (event.getActionMasked()) {
                case MotionEvent.ACTION_DOWN:
                    // The finger landed between tab slots; keep the stream so it can still become a drag.
                    downX = event.getX();
                    downY = event.getY();
                    tracking = inDragRange(downX);
                    return tracking;
                case MotionEvent.ACTION_MOVE:
                    if (!dragging && shouldStartDrag(event)) {
                        startDrag(event.getX());
                    }
                    if (dragging) {
                        updateDrag(event.getX());
                    }
                    return true;
                case MotionEvent.ACTION_UP:
                    if (dragging) {
                        finishDrag(event.getX());
                    }
                    tracking = false;
                    return true;
                case MotionEvent.ACTION_CANCEL:
                    cancelDrag();
                    tracking = false;
                    return true;
                default:
                    return true;
            }
        }

        private boolean shouldStartDrag(MotionEvent event) {
            if (!tracking) {
                return false;
            }
            float dx = Math.abs(event.getX() - downX);
            float dy = Math.abs(event.getY() - downY);
            return dx > touchSlop && dx > dy;
        }

        private void startDrag(float x) {
            dragging = true;
            if (getParent() != null) {
                getParent().requestDisallowInterceptTouchEvent(true);
            }
            int start = selectedIndex >= 0 && selectedIndex < slotCenters.length ? selectedIndex : Math.round(positionAt(x));
            showOverlay(overlayActive ? overlayPosition : start);
            hoverIndex = -1;
            dragListener.onDragStart();
            updateDrag(x);
        }

        private void updateDrag(float x) {
            if (slotCenters.length == 0) {
                return;
            }
            // The capsule tracks the finger 1:1; it must feel attached, so no easing here.
            overlayPosition = positionAt(x);
            int index = Math.round(overlayPosition);
            if (index != hoverIndex) {
                if (hoverIndex >= 0) {
                    performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK);
                }
                hoverIndex = index;
                dragListener.onDragHover(index);
            }
            invalidate();
        }

        private void finishDrag(float x) {
            dragging = false;
            if (slotCenters.length == 0) {
                overlayActive = false;
                setChildIndicatorsVisible(true);
                return;
            }
            int target = Math.round(positionAt(x));
            if (!dragListener.canSelect(target)) {
                target = Math.max(0, Math.min(selectedIndex, slotCenters.length - 1));
            }
            // Select on release only: switching pages mid-drag would make the content jump under the finger.
            animateOverlay(overlayPosition, target);
            dragListener.onDragSelect(target);
        }

        private void cancelDrag() {
            if (!dragging) {
                return;
            }
            dragging = false;
            int target = Math.max(0, Math.min(selectedIndex, slotCenters.length - 1));
            animateOverlay(overlayPosition, target);
            if (dragListener != null) {
                dragListener.onDragSelect(target);
            }
        }

        private void refreshSlotGeometry() {
            int end = style.isCurve() ? 0 : detachedTrailingIndex() >= 0 ? detachedTrailingIndex() : getChildCount();
            float[] centers = new float[end];
            float[] widths = new float[end];
            for (int index = 0; index < end; index++) {
                View child = getChildAt(index);
                centers[index] = (child.getLeft() + child.getRight()) / 2f;
                widths[index] = child.getWidth();
            }
            slotCenters = centers;
            slotWidths = widths;
            if (overlayActive) {
                overlayPosition = Math.max(0f, Math.min(overlayPosition, Math.max(0, end - 1)));
                invalidate();
            }
        }

        private void drawOverlayIndicator(Canvas canvas) {
            int count = slotCenters.length;
            if (!overlayActive || !indicatorEnabled || count == 0) {
                return;
            }
            float position = Math.max(0f, Math.min(overlayPosition, count - 1));
            int start = (int) Math.floor(position);
            int end = Math.min(start + 1, count - 1);
            float fraction = position - start;
            float centerX = slotCenters[start] + (slotCenters[end] - slotCenters[start]) * fraction;
            float inset = dp(FLOATING_INDICATOR_INSET_DP);
            float width = slotWidths[start] + (slotWidths[end] - slotWidths[start]) * fraction - inset * 2f;
            float height = getHeight() - inset * 2f;
            if (width <= 0f || height <= 0f) {
                return;
            }
            indicatorRect.set(centerX - width / 2f, inset, centerX + width / 2f, inset + height);
            canvas.drawRoundRect(indicatorRect, height / 2f, height / 2f, indicatorPaint);
        }

        void setTabbarStyle(TabbarStyle style, int backgroundColor, int centerIndex) {
            this.style = style;
            this.backgroundColor = backgroundColor;
            this.centerIndex = centerIndex;
            requestLayout();
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            backgroundPaint.setColor(backgroundColor);
            canvas.drawPath(backgroundPath(getWidth(), getHeight()), backgroundPaint);
            drawOverlayIndicator(canvas);
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int width = MeasureSpec.getSize(widthMeasureSpec);
            int height = MeasureSpec.getSize(heightMeasureSpec);
            if (style.isSidebar()) {
                int count = getChildCount();
                int slot = count == 0 ? height : Math.max(1, height / count);
                for (int index = 0; index < count; index++) {
                    measureChildExact(getChildAt(index), width, slot);
                }
                setMeasuredDimension(width, height);
                return;
            }
            if (hasCenterButton()) {
                int barHeight = dp(style.height);
                int barTop = dp(style.barTop());
                int centerGap = Math.min(dp(style.centerButtonDiameter + 4), Math.round(width * 0.34f));
                int leftWidth = Math.max(0, Math.round(width / 2f - centerGap / 2f));
                int rightX = Math.min(width, Math.round(width / 2f + centerGap / 2f));
                measureRange(0, centerIndex, leftWidth, barHeight);
                measureChildExact(getChildAt(centerIndex), dp(style.centerButtonDiameter), dp(style.centerButtonDiameter));
                measureRange(centerIndex + 1, getChildCount(), width - rightX, barHeight);
                setMeasuredDimension(width, Math.max(height, barTop + barHeight));
                return;
            }

            int trailingIndex = detachedTrailingIndex();
            if (trailingIndex >= 0) {
                int trailingDiameter = trailingDiameter(height);
                int capsuleWidth = Math.max(0, width - trailingDiameter - dp(10));
                measureRange(0, trailingIndex, capsuleWidth, height);
                measureChildExact(getChildAt(trailingIndex), trailingDiameter, trailingDiameter);
                measureRange(trailingIndex + 1, getChildCount(), 0, height);
                setMeasuredDimension(width, height);
                return;
            }

            measureRange(0, getChildCount(), width, height);
            setMeasuredDimension(width, height);
        }

        @Override
        protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
            int width = right - left;
            int height = bottom - top;
            if (style.isSidebar()) {
                int count = getChildCount();
                int slot = count == 0 ? 0 : height / count;
                for (int index = 0; index < count; index++) {
                    int childTop = index * slot;
                    getChildAt(index).layout(0, childTop, width, childTop + slot);
                }
                refreshSlotGeometry();
                return;
            }
            if (hasCenterButton()) {
                int barTop = dp(style.barTop());
                int barHeight = dp(style.height);
                int buttonDiameter = dp(style.centerButtonDiameter);
                int centerGap = Math.min(dp(style.centerButtonDiameter + 4), Math.round(width * 0.34f));
                int leftWidth = Math.max(0, Math.round(width / 2f - centerGap / 2f));
                int rightX = Math.min(width, Math.round(width / 2f + centerGap / 2f));
                View center = getChildAt(centerIndex);
                int centerTop = Math.max(0, barTop - dp(style.centerButtonLift));
                center.layout((width - buttonDiameter) / 2, centerTop, (width + buttonDiameter) / 2, centerTop + buttonDiameter);
                if (layoutRtl) {
                    layoutRange(0, centerIndex, rightX, barTop, width - rightX, barHeight);
                    layoutRange(centerIndex + 1, getChildCount(), 0, barTop, leftWidth, barHeight);
                } else {
                    layoutRange(0, centerIndex, 0, barTop, leftWidth, barHeight);
                    layoutRange(centerIndex + 1, getChildCount(), rightX, barTop, width - rightX, barHeight);
                }
                return;
            }

            int trailingIndex = detachedTrailingIndex();
            if (trailingIndex >= 0) {
                int trailingDiameter = trailingDiameter(height);
                int trailingGap = dp(10);
                int capsuleWidth = Math.max(0, width - trailingDiameter - trailingGap);
                View trailing = getChildAt(trailingIndex);
                int trailingTop = Math.max(0, (height - trailingDiameter) / 2);
                int trailingLeft = TabbarLayoutSupport.trailingActionLeft(width, trailingDiameter, layoutRtl);
                trailing.layout(trailingLeft, trailingTop, trailingLeft + trailingDiameter, trailingTop + trailingDiameter);
                int capsuleLeft = TabbarLayoutSupport.capsuleLeftForDetachedTrailing(trailingDiameter, trailingGap, layoutRtl);
                layoutRange(0, trailingIndex, capsuleLeft, 0, capsuleWidth, height);
                refreshSlotGeometry();
                return;
            }

            layoutRange(0, getChildCount(), 0, 0, width, height);
            refreshSlotGeometry();
        }

        /** The detached trailing circle matches the bar height, which shrinks while minimized. */
        private int trailingDiameter(int height) {
            return height > 0 ? Math.min(dp(style.height), height) : dp(style.height);
        }

        private boolean hasCenterButton() {
            return style.isCurve() && centerIndex >= 0 && centerIndex < getChildCount();
        }

        private int detachedTrailingIndex() {
            if (style.isCurve()) {
                return -1;
            }
            for (int index = 0; index < getChildCount(); index++) {
                Object tag = getChildAt(index).getTag();
                if ("detachedTrailing".equals(tag)) {
                    return index;
                }
            }
            return -1;
        }

        private int capsuleWidth(int width) {
            int trailingIndex = detachedTrailingIndex();
            if (trailingIndex < 0) {
                return width;
            }
            return Math.max(0, width - trailingDiameter(getHeight()) - dp(10));
        }

        private void measureRange(int start, int end, int width, int height) {
            int[] widths = slotWidths(start, end, width);
            for (int index = start; index < end; index++) {
                measureChildExact(getChildAt(index), widths[index - start], height);
            }
        }

        private void layoutRange(int start, int end, int left, int top, int width, int height) {
            int[] widths = slotWidths(start, end, width);
            int[] lefts = TabbarLayoutSupport.slotLefts(left, width, widths, layoutRtl);
            for (int index = start; index < end; index++) {
                int childWidth = widths[index - start];
                int childLeft = lefts[index - start];
                getChildAt(index).layout(childLeft, top, childLeft + childWidth, top + height);
            }
        }

        /**
         * Each tab gets the width its content needs; leftover space is shared equally so the gaps stay even. When the
         * bar is too narrow, slots shrink in proportion and long labels autosize down.
         */
        private int[] slotWidths(int start, int end, int width) {
            int count = Math.max(0, end - start);
            int[] widths = new int[count];
            if (count == 0) {
                return widths;
            }
            int total = 0;
            for (int index = 0; index < count; index++) {
                View child = getChildAt(start + index);
                int preferred = child instanceof TabButton ? ((TabButton) child).preferredWidth : 0;
                widths[index] = Math.max(preferred, 0);
                total += widths[index];
            }
            if (total <= 0) {
                for (int index = 0; index < count; index++) {
                    widths[index] = width / count;
                }
            } else if (total <= width) {
                int extra = (width - total) / count;
                for (int index = 0; index < count; index++) {
                    widths[index] += extra;
                }
            } else {
                for (int index = 0; index < count; index++) {
                    widths[index] = (int) ((long) widths[index] * width / total);
                }
            }
            return widths;
        }

        private void measureChildExact(View child, int width, int height) {
            child.measure(
                MeasureSpec.makeMeasureSpec(Math.max(0, width), MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(Math.max(0, height), MeasureSpec.EXACTLY)
            );
        }

        Path chromeBackgroundPath(int width, int height) {
            return backgroundPath(width, height);
        }

        private Path backgroundPath(int width, int height) {
            Path path = new Path();
            if (style.isSidebar()) {
                float radius = Math.min(dp(28), width / 2f);
                path.addRoundRect(new RectF(0, 0, width, height), radius, radius, Path.Direction.CW);
                return path;
            }
            if (!style.isCurve()) {
                return TabbarChromeSupport.buildFloatingTabbarPath(
                    width,
                    height,
                    Math.min(dp(style.cornerRadius), height / 2f),
                    trailingDiameter(height),
                    dp(10),
                    detachedTrailingIndex() >= 0,
                    layoutRtl
                );
            }
            float barTop = dp(style.barTop());
            float barHeight = dp(style.height);
            float cornerRadius = Math.min(dp(style.cornerRadius), barHeight / 2f);
            float centerX = width / 2f;
            float centerRadius = dp(style.centerButtonDiameter) / 2f;
            float centerTop = Math.max(0f, barTop - dp(style.centerButtonLift));
            float centerY = centerTop + centerRadius;
            float dyToBarTop = barTop - centerY;
            float shoulderWidth = (float) Math.sqrt(Math.max(0f, centerRadius * centerRadius - dyToBarTop * dyToBarTop));
            float leftShoulder = Math.max(cornerRadius, centerX - shoulderWidth);
            float rightShoulder = Math.min(width - cornerRadius, centerX + shoulderWidth);
            RectF barRect = new RectF(0, barTop, width, barTop + barHeight);
            RectF centerRect = new RectF(centerX - centerRadius, centerY - centerRadius, centerX + centerRadius, centerY + centerRadius);
            float startAngle = (float) Math.toDegrees(Math.atan2(dyToBarTop, -shoulderWidth));
            float endAngle = (float) Math.toDegrees(Math.atan2(dyToBarTop, shoulderWidth));
            float sweepAngle = endAngle - startAngle;
            if (sweepAngle <= 0f) {
                sweepAngle += 360f;
            }

            path.moveTo(barRect.left + cornerRadius, barRect.top);
            path.lineTo(leftShoulder, barRect.top);
            if (shoulderWidth > 0f) {
                path.arcTo(centerRect, startAngle, sweepAngle, false);
            }
            path.lineTo(barRect.right - cornerRadius, barRect.top);
            path.quadTo(barRect.right, barRect.top, barRect.right, barRect.top + cornerRadius);
            path.lineTo(barRect.right, barRect.bottom - cornerRadius);
            path.quadTo(barRect.right, barRect.bottom, barRect.right - cornerRadius, barRect.bottom);
            path.lineTo(barRect.left + cornerRadius, barRect.bottom);
            path.quadTo(barRect.left, barRect.bottom, barRect.left, barRect.bottom - cornerRadius);
            path.lineTo(barRect.left, barRect.top + cornerRadius);
            path.quadTo(barRect.left, barRect.top, barRect.left + cornerRadius, barRect.top);
            path.close();
            return path;
        }

        private int dp(int value) {
            return Math.round(value * getResources().getDisplayMetrics().density);
        }
    }

    private static final class SvgIconRenderer {

        private static final Pattern NUMBER_PATTERN = Pattern.compile("[-+]?(?:\\d*\\.\\d+|\\d+\\.?)(?:[eE][-+]?\\d+)?");

        static Drawable render(Resources resources, String svg, int iconSizeDp) {
            return render(resources, svg, (float) iconSizeDp, (float) iconSizeDp);
        }

        /** Renders at widthDp x heightDp, so wide marks such as wordmarks keep their aspect ratio. */
        static Drawable render(Resources resources, String svg, float widthDp, float heightDp) {
            float density = resources.getDisplayMetrics().density;
            int widthPx = Math.max(1, Math.round(widthDp * density));
            int heightPx = Math.max(1, Math.round(heightDp * density));
            Bitmap bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(bitmap);
            RectF viewBox = viewBox(svg, widthDp, heightDp);
            canvas.scale(widthPx / Math.max(viewBox.width(), 1f), heightPx / Math.max(viewBox.height(), 1f));
            canvas.translate(-viewBox.left, -viewBox.top);

            try {
                XmlPullParser parser = XmlPullParserFactory.newInstance().newPullParser();
                parser.setInput(new StringReader(svg));
                ArrayDeque<SvgStyle> styles = new ArrayDeque<>();
                styles.push(new SvgStyle());
                int event = parser.getEventType();
                while (event != XmlPullParser.END_DOCUMENT) {
                    if (event == XmlPullParser.START_TAG) {
                        SvgStyle style = styles.peek().copy();
                        style.apply(parser);
                        styles.push(style);
                        drawElement(canvas, parser, style);
                    } else if (event == XmlPullParser.END_TAG && styles.size() > 1) {
                        styles.pop();
                    }
                    event = parser.next();
                }
            } catch (Exception ignored) {}

            BitmapDrawable drawable = new BitmapDrawable(resources, bitmap);
            drawable.setBounds(0, 0, widthPx, heightPx);
            return drawable;
        }

        private static void drawElement(Canvas canvas, XmlPullParser parser, SvgStyle style) {
            String name = parser.getName().toLowerCase();
            if ("path".equals(name)) {
                Path path = path(attr(parser, "d"));
                if (path != null) {
                    drawPath(canvas, path, style);
                }
            } else if ("line".equals(name)) {
                Path path = new Path();
                path.moveTo(value(attr(parser, "x1")), value(attr(parser, "y1")));
                path.lineTo(value(attr(parser, "x2")), value(attr(parser, "y2")));
                drawPath(canvas, path, style);
            } else if ("polyline".equals(name) || "polygon".equals(name)) {
                Path path = pointsPath(attr(parser, "points"), "polygon".equals(name));
                if (path != null) {
                    drawPath(canvas, path, style);
                }
            } else if ("circle".equals(name)) {
                float cx = value(attr(parser, "cx"));
                float cy = value(attr(parser, "cy"));
                float radius = value(attr(parser, "r"));
                Path path = new Path();
                path.addOval(new RectF(cx - radius, cy - radius, cx + radius, cy + radius), Path.Direction.CW);
                drawPath(canvas, path, style);
            } else if ("rect".equals(name)) {
                float x = value(attr(parser, "x"));
                float y = value(attr(parser, "y"));
                float width = value(attr(parser, "width"));
                float height = value(attr(parser, "height"));
                float radius = Math.max(value(attr(parser, "rx")), value(attr(parser, "ry")));
                Path path = new Path();
                RectF rect = new RectF(x, y, x + width, y + height);
                if (radius > 0) {
                    path.addRoundRect(rect, radius, radius, Path.Direction.CW);
                } else {
                    path.addRect(rect, Path.Direction.CW);
                }
                drawPath(canvas, path, style);
            }
        }

        private static void drawPath(Canvas canvas, Path path, SvgStyle style) {
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            paint.setColor(Color.BLACK);
            paint.setAlpha(style.alpha);
            if (style.fill) {
                paint.setStyle(Paint.Style.FILL);
                canvas.drawPath(path, paint);
            }
            if (style.stroke) {
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(style.strokeWidth);
                paint.setStrokeCap(style.lineCap);
                paint.setStrokeJoin(style.lineJoin);
                canvas.drawPath(path, paint);
            }
        }

        private static Path path(String data) {
            if (data == null || data.isEmpty()) {
                return null;
            }
            try {
                String normalized = SvgPathDataSupport.normalizeArcFlagsInPathData(data);
                return PathParser.createPathFromPathData(normalized);
            } catch (RuntimeException ignored) {
                return null;
            }
        }

        private static Path pointsPath(String value, boolean closed) {
            List<Float> numbers = numbers(value);
            if (numbers.size() < 2) {
                return null;
            }
            Path path = new Path();
            path.moveTo(numbers.get(0), numbers.get(1));
            for (int index = 2; index + 1 < numbers.size(); index += 2) {
                path.lineTo(numbers.get(index), numbers.get(index + 1));
            }
            if (closed) {
                path.close();
            }
            return path;
        }

        private static RectF viewBox(String svg, float fallbackWidth, float fallbackHeight) {
            List<Float> viewBoxValues = numbers(attribute(svg, "viewBox"));
            if (viewBoxValues.size() >= 4) {
                return new RectF(
                    viewBoxValues.get(0),
                    viewBoxValues.get(1),
                    viewBoxValues.get(0) + viewBoxValues.get(2),
                    viewBoxValues.get(1) + viewBoxValues.get(3)
                );
            }
            float width = value(attribute(svg, "width"));
            float height = value(attribute(svg, "height"));
            if (width <= 0 || height <= 0) {
                width = fallbackWidth;
                height = fallbackHeight;
            }
            return new RectF(0, 0, width, height);
        }

        private static String attribute(String svg, String name) {
            if (svg == null) {
                return null;
            }
            Pattern pattern = Pattern.compile(name + "\\s*=\\s*[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE);
            Matcher matcher = pattern.matcher(svg);
            return matcher.find() ? matcher.group(1) : null;
        }

        private static float value(String value) {
            Float parsed = length(value);
            return parsed == null ? 0f : parsed;
        }

        private static List<Float> numbers(String value) {
            List<Float> numbers = new ArrayList<>();
            if (value == null) {
                return numbers;
            }
            Matcher matcher = NUMBER_PATTERN.matcher(value);
            while (matcher.find()) {
                numbers.add(Float.parseFloat(matcher.group()));
            }
            return numbers;
        }
    }

    private void applyToolbarColors(Toolbar nativeToolbar, JSObject colors) {
        boolean dynamic = Boolean.TRUE.equals(colors.getBool("dynamic"));
        int tintFallback = dynamic ? dynamicColor("system_accent1_600", tintColor) : tintColor;
        int backgroundFallback = dynamic
            ? withAlpha(dynamicColor(isNightMode() ? "system_neutral1_900" : "system_neutral1_50", Color.WHITE), 235)
            : Color.argb(225, 255, 255, 255);
        int foregroundFallback = dynamic
            ? dynamicColor(isNightMode() ? "system_neutral1_50" : "system_neutral1_900", Color.rgb(20, 24, 32))
            : Color.rgb(20, 24, 32);
        int tint = parseColor(colors.getString("tint", null), tintFallback);
        int background = parseColor(colors.getString("background", null), backgroundFallback);
        navbarBackgroundColor = background;
        int foreground = parseColor(colors.getString("foreground", null), foregroundFallback);
        tintColor = tint;
        navbarForegroundColor = foreground;
        nativeToolbar.setTitleTextColor(foreground);
        if (largeTitleView != null) {
            largeTitleView.setTextColor(foreground);
        }
        nativeToolbar.setSubtitleTextColor(withAlpha(foreground, 190));
        Drawable navigationIcon = nativeToolbar.getNavigationIcon();
        if (navigationIcon != null) {
            Drawable tintedIcon = navigationIcon.mutate();
            tintedIcon.setTint(tint);
            nativeToolbar.setNavigationIcon(tintedIcon);
        }
        nativeToolbar.setBackgroundColor(Color.TRANSPARENT);
        applyChromeBackground(navbarContainer, navbarGlassSurface, background, navbarGlassOptions, 0f);
        for (int index = 0; index < nativeToolbar.getMenu().size(); index++) {
            Drawable icon = nativeToolbar.getMenu().getItem(index).getIcon();
            if (icon != null) {
                icon.mutate().setTint(tint);
            }
        }
    }

    private TabbarStyle makeTabbarStyle(JSObject rawStyle) {
        String requestedShape = rawStyle.getString("shape", "floating");
        boolean curve = "curve".equalsIgnoreCase(requestedShape);
        int centerButtonDiameter = Math.max(styleDimension(rawStyle, "centerButtonDiameter", 56), 44);
        int height = Math.max(styleDimension(rawStyle, "height", curve ? 80 : DEFAULT_TABBAR_DP), 44);
        int centerButtonLift = Math.max(styleDimension(rawStyle, "centerButtonLift", centerButtonDiameter / 2), 0);
        int bottomGap = Math.max(styleDimension(rawStyle, "bottomGap", curve ? 0 : 10), 0);
        int horizontalMargin = Math.max(styleDimension(rawStyle, "horizontalMargin", curve ? 0 : 24), 0);
        int maxWidth = Math.max(styleDimension(rawStyle, "maxWidth", curve ? 0 : 430), 0);
        int cornerRadius = Math.max(styleDimension(rawStyle, "cornerRadius", curve ? 0 : height / 2), 0);
        int centerButtonColor = parseColor(rawStyle.getString("centerButtonColor", null), tintColor);
        int centerButtonIconColor = parseColor(rawStyle.getString("centerButtonIconColor", null), Color.WHITE);
        String requestedAlignment = rawStyle.getString("alignment", "center");
        String alignment = "start".equalsIgnoreCase(requestedAlignment)
            ? "start"
            : ("end".equalsIgnoreCase(requestedAlignment) ? "end" : "center");
        String requestedPlacement = rawStyle.getString("placement", "auto");
        String placement = curve
            ? "bottom"
            : ("sidebar".equalsIgnoreCase(requestedPlacement)
                    ? "sidebar"
                    : ("bottom".equalsIgnoreCase(requestedPlacement) ? "bottom" : "auto"));
        return new TabbarStyle(
            curve ? "curve" : "floating",
            height,
            horizontalMargin,
            maxWidth,
            bottomGap,
            cornerRadius,
            rawStyle.getString("centerItemId", null),
            centerButtonDiameter,
            centerButtonLift,
            centerButtonColor,
            centerButtonIconColor,
            alignment,
            curve ? "bottom" : placement
        );
    }

    private int styleDimension(JSObject rawStyle, String key, int fallback) {
        if (rawStyle == null || !rawStyle.has(key)) {
            return fallback;
        }
        return (int) Math.round(rawStyle.optDouble(key, fallback));
    }

    private int centerTabIndex() {
        if (!tabbarStyle.isCurve() || tabItems.isEmpty()) {
            return -1;
        }
        if (tabbarStyle.centerItemId != null) {
            for (int index = 0; index < tabItems.size(); index++) {
                if (tabbarStyle.centerItemId.equals(tabItems.get(index).id)) {
                    return index;
                }
            }
        }
        return tabItems.size() / 2;
    }

    private void applyTabbarColors(PluginCall call, JSObject colors) {
        boolean dynamic = Boolean.TRUE.equals(colors.getBool("dynamic"));
        int tintFallback = dynamic ? dynamicColor("system_accent1_600", tintColor) : tintColor;
        int inactiveFallback = dynamic ? dynamicColor("system_neutral2_600", inactiveTintColor) : inactiveTintColor;
        int backgroundFallback = dynamic
            ? dynamicColor(isNightMode() ? "system_neutral1_900" : "system_neutral1_50", DEFAULT_TABBAR_BACKGROUND_COLOR)
            : DEFAULT_TABBAR_BACKGROUND_COLOR;
        tintColor = parseColor(colors.getString("tint", null), tintFallback);
        inactiveTintColor = parseColor(colors.getString("inactiveTint", null), inactiveFallback);
        tabbarBackgroundColor = parseColor(colors.getString("background", null), backgroundFallback);
        applyTabbarBackground();
    }

    private void applyTabbarBackground() {
        applyTabbarBackground(centerTabIndex());
    }

    private void applyTabbarBackground(int centerIndex) {
        if (tabbar == null) {
            return;
        }
        int drawColor = resolvedTabbarSurfaceColor();
        if (tabbarBackdrop != null) {
            tabbarBackdrop.setBackgroundColor(drawColor);
        }

        // The tabbar draws its own translucent fill (see resolvedTabbarSurfaceColor); there is no live blur.
        hideGlassSurface(tabbarGlassSurface);
        if (tabbarContainer != null) {
            tabbarContainer.setBackgroundColor(Color.TRANSPARENT);
        }
        tabbar.setTabbarStyle(tabbarStyle, drawColor, centerIndex);
        applyTabbarContainerOutline();
    }

    private GlassOptions resolveTabbarGlassOptions(PluginCall call) {
        if (tabbarGlassConfig != null) {
            return GlassOptions.from(tabbarGlassConfig, defaultGlassOptions);
        }
        boolean apiAtLeastS = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S;
        if (
            TabbarChromeSupport.shouldEnableDefaultLiquidGlass(apiAtLeastS, tabbarStyle.isCurve(), false)
            && (!configureSpecifiedGlassEffect || defaultGlassOptions.isLiquidGlass())
        ) {
            return GlassOptions.from(new JSObject().put("effect", "liquidGlass"), defaultGlassOptions);
        }
        return GlassOptions.from(null, defaultGlassOptions);
    }

    private int resolvedTabbarSurfaceColor() {
        if (!supportsBlur()) {
            return opaque(tabbarBackgroundColor);
        }
        GlassOptions resolvedGlassOptions = tabbarGlassOptions == null ? GlassOptions.defaults() : tabbarGlassOptions;
        if (resolvedGlassOptions.isLiquidGlass()) {
            return glassSurfaceColor(tabbarBackgroundColor, resolvedGlassOptions);
        }
        if (!tabbarStyle.isCurve()) {
            return glassSurfaceColor(tabbarBackgroundColor, resolvedGlassOptions);
        }
        return tabbarBackgroundColor;
    }

    private void reapplyVisibleChromeBackgrounds() {
        if (navbarContainer != null && navbarContainer.getVisibility() == View.VISIBLE) {
            applyChromeBackground(navbarContainer, navbarGlassSurface, navbarBackgroundColor, navbarGlassOptions, 0f);
        }
        if (tabbarContainer != null && tabbarContainer.getVisibility() == View.VISIBLE) {
            applyTabbarBackground();
        }
    }

    private void applyChromeBackground(
        ViewGroup container,
        View surface,
        int background,
        GlassOptions glassOptions,
        float cornerRadius
    ) {
        if (container == null) {
            return;
        }
        GlassOptions resolvedGlassOptions = glassOptions == null ? GlassOptions.defaults() : glassOptions;
        if (!supportsBlur()) {
            // Without blur a translucent bar lets the page read through, so older Android gets a solid bar.
            hideGlassSurface(surface);
            container.setBackground(chromeBackgroundDrawable(opaque(background), cornerRadius));
            return;
        }
        if (!resolvedGlassOptions.isLiquidGlass()) {
            hideGlassSurface(surface);
            container.setBackground(chromeBackgroundDrawable(background, cornerRadius));
            return;
        }

        container.setBackgroundColor(Color.TRANSPARENT);
        int surfaceColor = glassSurfaceColor(background, resolvedGlassOptions);
        if (surface != null) {
            surface.setBackground(chromeBackgroundDrawable(surfaceColor, cornerRadius));
            surface.setVisibility(View.VISIBLE);
        }
    }

    /** The page blur behind the bars needs CSS backdrop-filter and enough GPU, so it starts at Android 12. */
    private boolean supportsBlur() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S;
    }

    private int opaque(int color) {
        return color | 0xFF000000;
    }

    private void hideGlassSurface(View surface) {
        if (surface != null) {
            surface.setBackground(null);
            surface.setVisibility(View.GONE);
        }
    }

    private Drawable chromeBackgroundDrawable(int color, float cornerRadius) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        if (cornerRadius > 0f) {
            drawable.setCornerRadius(cornerRadius);
        }
        return drawable;
    }

    private int glassSurfaceColor(int background, GlassOptions glassOptions) {
        return withAlpha(background, Math.round(Color.alpha(background) * (float) glassOptions.surfaceAlpha));
    }

    private int parseColor(String value, int fallback) {
        if (value == null || value.isEmpty()) {
            return fallback;
        }
        if ("android:dynamicPrimary".equals(value) || "system:primary".equals(value)) {
            return dynamicColor("system_accent1_600", fallback);
        }
        if ("android:dynamicSurface".equals(value) || "system:surface".equals(value)) {
            return dynamicColor(isNightMode() ? "system_neutral1_900" : "system_neutral1_50", fallback);
        }
        try {
            return Color.parseColor(value);
        } catch (IllegalArgumentException ignored) {
            return fallback;
        }
    }

    private Integer parseColorOrNull(String value) {
        if (value == null || value.isEmpty()) {
            return null;
        }
        if ("android:dynamicPrimary".equals(value) || "system:primary".equals(value)) {
            return dynamicColor("system_accent1_600", tintColor);
        }
        if ("android:dynamicSurface".equals(value) || "system:surface".equals(value)) {
            return dynamicColor(isNightMode() ? "system_neutral1_900" : "system_neutral1_50", Color.WHITE);
        }
        try {
            return Color.parseColor(value);
        } catch (IllegalArgumentException ignored) {
            return null;
        }
    }

    private Integer colorOption(PluginCall call, JSObject colors, String directKey, String colorKey, Integer fallback) {
        Integer direct = parseColorOrNull(call.getString(directKey, null));
        if (direct != null) {
            return direct;
        }
        Integer nested = parseColorOrNull(colors.getString(colorKey, null));
        return nested == null ? fallback : nested;
    }

    private int dynamicColor(String name, int fallback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return fallback;
        }
        int id = Resources.getSystem().getIdentifier(name, "color", "android");
        if (id == 0) {
            return fallback;
        }
        return getContext().getColor(id);
    }

    private int withAlpha(int color, int alpha) {
        return Color.argb(Math.max(0, Math.min(255, alpha)), Color.red(color), Color.green(color), Color.blue(color));
    }

    private Drawable selectableItemBackground() {
        TypedValue outValue = new TypedValue();
        getContext().getTheme().resolveAttribute(android.R.attr.selectableItemBackgroundBorderless, outValue, true);
        return AppCompatResources.getDrawable(getContext(), outValue.resourceId);
    }

    private boolean isNightMode() {
        int mode = getContext().getResources().getConfiguration().uiMode & Configuration.UI_MODE_NIGHT_MASK;
        return mode == Configuration.UI_MODE_NIGHT_YES;
    }

    private void fillContainer(View view) {
        if (view != null) {
            view.setLayoutParams(new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        }
    }

    private void layoutChrome() {
        FrameLayout root = contentRoot();
        if (root == null) {
            return;
        }
        int status = nativeStatusBarInset();
        int bottom = nativeNavigationBarInset();
        int navbarToolbar = navbarScrollCollapsed ? 0 : navbarBarHeight(navbarLargeProgress) + navbarAccessoryHeight();
        int navbarHeight = navbarVisible ? status + navbarToolbar : 0;
        boolean tabbarLayoutVisible = tabbarVisible || tabbarChromeHideAnimating;

        if (navbarContainer != null) {
            FrameLayout.LayoutParams containerParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                navbarHeight,
                Gravity.TOP
            );
            navbarContainer.setLayoutParams(containerParams);
            FrameLayout.LayoutParams toolbarParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(DEFAULT_NAVBAR_DP),
                Gravity.TOP
            );
            toolbarParams.topMargin = status;
            toolbar.setLayoutParams(toolbarParams);
            FrameLayout.LayoutParams largeTitleParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(NavbarLargeTitleSupport.LARGE_TITLE_ROW_DP),
                Gravity.TOP
            );
            largeTitleParams.topMargin = status + dp(DEFAULT_NAVBAR_DP);
            largeTitleView.setLayoutParams(largeTitleParams);
            int searchHeight = navbarSearchHeight();
            if (navbarSearchField != null) {
                FrameLayout.LayoutParams searchParams = new FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    searchHeight > 0 ? dp(36) : 0,
                    Gravity.TOP
                );
                searchParams.topMargin = status + navbarBarHeight(navbarLargeProgress) + dp(8);
                searchParams.leftMargin = dp(16);
                searchParams.rightMargin = dp(16);
                navbarSearchField.setLayoutParams(searchParams);
                navbarSearchField.setVisibility(searchHeight > 0 ? View.VISIBLE : View.GONE);
            }
            FrameLayout.LayoutParams segmentsParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                navbarSegmentsHeight(),
                Gravity.TOP
            );
            segmentsParams.topMargin = status + navbarBarHeight(navbarLargeProgress) + searchHeight;
            navbarSegments.setLayoutParams(segmentsParams);
            fillContainer(navbarGlassSurface);
        }

        if (tabbarBackdrop != null) {
            // Only the edge-to-edge curve bar extends its surface under the gesture area. A floating
            // tabbar must leave the page visible below it, or it sits on a solid band.
            int backdropHeight = tabbarLayoutVisible && tabbarStyle.isCurve() ? bottom + dp(tabbarStyle.bottomGap) : 0;
            FrameLayout.LayoutParams backdropParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                backdropHeight,
                Gravity.BOTTOM
            );
            tabbarBackdrop.setLayoutParams(backdropParams);
            tabbarBackdrop.setBackgroundColor(resolvedTabbarSurfaceColor());
            tabbarBackdrop.setVisibility(tabbarLayoutVisible && backdropHeight > 0 ? View.VISIBLE : View.GONE);
        }
        layoutTabbarContainer();

        if (tabbar != null) {
            FrameLayout.LayoutParams tabbarParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            );
            tabbar.setLayoutParams(tabbarParams);
            tabbar.setPadding(0, 0, 0, 0);
            applyTabbarBackground();
        }

        bringChromeToFront();
    }

    /** Sizes the tabbar container, including the minimize-on-scroll shrink. */
    private void layoutTabbarContainer() {
        FrameLayout root = contentRoot();
        if (root == null || tabbarContainer == null) {
            return;
        }
        int bottom = nativeNavigationBarInset();
        boolean tabbarLayoutVisible = tabbarVisible || tabbarChromeHideAnimating;
        int rootWidth = root.getWidth() > 0 ? root.getWidth() : Resources.getSystem().getDisplayMetrics().widthPixels;
        int rootHeight = root.getHeight() > 0 ? root.getHeight() : Resources.getSystem().getDisplayMetrics().heightPixels;
        boolean sidebar = tabbarStyle.isSidebar();
        boolean layoutRtl = tabbar != null && tabbar.isLayoutRtl();
        int tabbarWidth;
        int tabbarHeight;
        int gravity;
        int leftMargin = 0;
        int topMargin = 0;
        int bottomMargin;
        if (sidebar) {
            int navbarOccupied = navbarVisible
                ? nativeStatusBarInset() + navbarBarHeight(navbarLargeProgress) + navbarAccessoryHeight()
                : nativeStatusBarInset();
            tabbarWidth = dp(TabbarLayoutSupport.SIDEBAR_WIDTH_DP);
            topMargin = navbarOccupied + dp(8);
            bottomMargin = bottom + dp(8);
            tabbarHeight = Math.max(dp(120), rootHeight - topMargin - bottomMargin);
            gravity = Gravity.TOP | Gravity.LEFT;
            leftMargin = TabbarLayoutSupport.sidebarOriginX(rootWidth, tabbarWidth, dp(12), layoutRtl);
        } else {
            bottomMargin = tabbarLayoutVisible ? bottom + dp(tabbarStyle.bottomGap) : bottom;
            float minimize = tabbarStyle.isCurve() ? 0f : tabbarMinimizeProgress;
            tabbarHeight = dp(tabbarStyle.totalHeight()) - Math.round(dp(TABBAR_MINIMIZE_HEIGHT_REDUCTION_DP) * minimize);
            int sideInset = Math.round(dp(TABBAR_MINIMIZE_SIDE_INSET_DP) * minimize);
            int availableWidth = Math.max(0, rootWidth - dp(tabbarStyle.horizontalMargin) * 2);
            int maxWidth = tabbarStyle.maxWidth > 0 ? dp(tabbarStyle.maxWidth) : availableWidth;
            boolean hasDetachedTrailing = !tabbarStyle.isCurve() && tabItems.stream().anyMatch((item) -> item.detachedTrailing);
            int trailingExtra = hasDetachedTrailing ? Math.min(dp(tabbarStyle.height), tabbarHeight) + dp(10) : 0;
            tabbarWidth = Math.max(0, Math.min(availableWidth, maxWidth + trailingExtra) - sideInset * 2);
            gravity = Gravity.BOTTOM | Gravity.LEFT;
            leftMargin = TabbarLayoutSupport.floatingBarOriginX(
                rootWidth,
                tabbarWidth,
                dp(tabbarStyle.horizontalMargin) + sideInset,
                tabbarStyle.alignment,
                layoutRtl
            );
        }
        ViewGroup.LayoutParams current = tabbarContainer.getLayoutParams();
        if (
            current instanceof FrameLayout.LayoutParams &&
            current.width == tabbarWidth &&
            current.height == tabbarHeight &&
            ((FrameLayout.LayoutParams) current).bottomMargin == bottomMargin &&
            ((FrameLayout.LayoutParams) current).topMargin == topMargin &&
            ((FrameLayout.LayoutParams) current).leftMargin == leftMargin &&
            ((FrameLayout.LayoutParams) current).gravity == gravity
        ) {
            // Same size: skip the relayout, but the outline still depends on the current tabs.
        } else {
            FrameLayout.LayoutParams tabbarContainerParams = new FrameLayout.LayoutParams(tabbarWidth, tabbarHeight, gravity);
            tabbarContainerParams.bottomMargin = bottomMargin;
            tabbarContainerParams.topMargin = topMargin;
            tabbarContainerParams.leftMargin = leftMargin;
            tabbarContainer.setLayoutParams(tabbarContainerParams);
            fillContainer(tabbarGlassSurface);
        }
        tabbarContainer.invalidateOutline();
        if (tabbarGlassSurface != null) {
            tabbarGlassSurface.invalidateOutline();
        }
    }

    private void setTabbarChromeVisible(boolean visible, boolean animated) {
        if (!animated) {
            tabbarChromeHideAnimating = false;
            int visibility = visible ? View.VISIBLE : View.GONE;
            if (tabbar != null) {
                tabbar.setVisibility(visibility);
            }
            if (tabbarContainer != null) {
                tabbarContainer.animate().cancel();
                tabbarContainer.setTranslationY(0f);
                tabbarContainer.setAlpha(1f);
                tabbarContainer.setVisibility(visibility);
            }
            if (tabbarBackdrop != null) {
                tabbarBackdrop.animate().cancel();
                tabbarBackdrop.setAlpha(1f);
                tabbarBackdrop.setVisibility(visible && tabbarVisible ? View.VISIBLE : View.GONE);
            }
            return;
        }

        if (tabbarContainer == null) {
            setTabbarChromeVisible(visible, false);
            return;
        }

        boolean alreadyShown =
            tabbarContainer.getVisibility() == View.VISIBLE &&
            !tabbarChromeHideAnimating &&
            tabbarContainer.getAlpha() == 1f &&
            tabbarContainer.getTranslationY() == 0f;
        if (visible && alreadyShown) {
            // Updating a visible tab bar (e.g. a new selection) must not replay the slide-in.
            setTabbarChromeVisible(true, false);
            return;
        }

        float slideDistance = tabbarSlideDistance();
        tabbarContainer.animate().cancel();
        if (tabbarBackdrop != null) {
            tabbarBackdrop.animate().cancel();
        }

        if (!visible) {
            tabbarChromeHideAnimating = true;
            tabbarContainer
                .animate()
                .translationY(slideDistance)
                .alpha(0f)
                .setDuration(TabbarChromeSupport.TABBAR_VISIBILITY_ANIMATION_MS)
                .withEndAction(() -> {
                    tabbarChromeHideAnimating = false;
                    if (tabbar != null) {
                        tabbar.setVisibility(View.GONE);
                    }
                    tabbarContainer.setVisibility(View.GONE);
                    if (tabbarBackdrop != null) {
                        tabbarBackdrop.setVisibility(View.GONE);
                    }
                })
                .start();
            if (tabbarBackdrop != null) {
                tabbarBackdrop.animate().alpha(0f).setDuration(TabbarChromeSupport.TABBAR_VISIBILITY_ANIMATION_MS).start();
            }
            return;
        }

        tabbarChromeHideAnimating = false;
        tabbarContainer.setVisibility(View.VISIBLE);
        tabbarContainer.setAlpha(0f);
        tabbarContainer.setTranslationY(slideDistance);
        if (tabbarBackdrop != null) {
            tabbarBackdrop.setVisibility(View.VISIBLE);
            tabbarBackdrop.setAlpha(0f);
        }
        if (tabbar != null) {
            tabbar.setVisibility(View.VISIBLE);
        }
        tabbarContainer
            .animate()
            .translationY(0f)
            .alpha(1f)
            .setDuration(TabbarChromeSupport.TABBAR_VISIBILITY_ANIMATION_MS)
            .start();
        if (tabbarBackdrop != null) {
            tabbarBackdrop.animate().alpha(1f).setDuration(TabbarChromeSupport.TABBAR_VISIBILITY_ANIMATION_MS).start();
        }
    }

    private float tabbarSlideDistance() {
        if (tabbarContainer == null) {
            return dp(tabbarStyle.totalHeight() + tabbarStyle.bottomGap);
        }
        ViewGroup.LayoutParams params = tabbarContainer.getLayoutParams();
        int bottomMargin = params instanceof ViewGroup.MarginLayoutParams ? ((ViewGroup.MarginLayoutParams) params).bottomMargin : 0;
        return TabbarChromeSupport.tabbarSlideDistancePx(
            tabbarContainer.getHeight(),
            bottomMargin,
            dp(tabbarStyle.totalHeight() + tabbarStyle.bottomGap)
        );
    }

    private void bringChromeToFront() {
        if (navbarContainer != null) {
            navbarContainer.bringToFront();
        }
        if (tabbarBackdrop != null) {
            tabbarBackdrop.bringToFront();
        }
        if (tabbar != null) {
            tabbar.bringToFront();
        }
        if (tabbarContainer != null) {
            tabbarContainer.bringToFront();
        }
    }

    private void updateInsetsAndNotify() {
        layoutChrome();
        JSObject insets = currentInsets();
        JSObject event = new JSObject();
        event.put("insets", insets);
        notifyListeners("safeAreaChanged", event);
        applyTabbarEdgeBlur(insets);
        applyNavbarEdgeBlur(insets);
        pullToRefresh.setTopOffset(pullToRefreshTopPx());
        if ("none".equals(contentInsetMode) || getBridge() == null || getBridge().getWebView() == null) {
            return;
        }
        String script =
            "(() => {" +
            "const root=document.documentElement;" +
            "root.style.setProperty('--cap-native-navigation-top','" +
            insets.getInteger("top", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-navigation-right','" +
            insets.getInteger("right", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-navigation-bottom','" +
            insets.getInteger("bottom", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-navigation-left','" +
            insets.getInteger("left", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-navbar-height','" +
            insets.getInteger("navbarHeight", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-tabbar-height','" +
            insets.getInteger("tabbarHeight", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-system-tabbar-height','" +
            insets.getInteger("systemTabbarHeight", 0) +
            "px');" +
            "root.style.setProperty('--cap-native-navigation-vertical-bar-edge','');" +
            "root.style.setProperty('--cap-native-navigation-division-x','0px');" +
            "root.style.setProperty('--cap-native-navigation-division-width','0px');" +
            "window.dispatchEvent(new CustomEvent('capNativeNavigation:safeAreaChanged',{detail:{insets:" +
            insets.toString() +
            "}}));" +
            "})();";
        getBridge().getWebView().evaluateJavascript(script, null);
    }

    /**
     * Progressive blur under the tabbar, drawn by the page itself with CSS backdrop-filter. Blurring the WebView
     * from native code breaks scrolling (see #77), so this stays in the web layer.
     */
    private void applyTabbarEdgeBlur(JSObject insets) {
        if (getBridge() == null || getBridge().getWebView() == null) {
            return;
        }
        boolean active = enabled && tabbarEdgeBlur && tabbarVisible && supportsBlur();
        int height = active ? insets.getInteger("tabbarHeight", 0) + TabbarChromeSupport.EDGE_BLUR_BLEED_CSS_PX : 0;
        getBridge().getWebView().evaluateJavascript(TabbarChromeSupport.edgeBlurScript(height), null);
    }

    /** Same progressive blur as {@link #applyTabbarEdgeBlur}, pinned under the navbar. */
    private void applyNavbarEdgeBlur(JSObject insets) {
        if (getBridge() == null || getBridge().getWebView() == null) {
            return;
        }
        int navbarHeight = insets.getInteger("navbarHeight", 0);
        boolean active = enabled && navbarEdgeBlur && navbarVisible && navbarHeight > 0 && supportsBlur();
        int height = active ? navbarHeight + TabbarChromeSupport.EDGE_BLUR_BLEED_CSS_PX : 0;
        getBridge().getWebView().evaluateJavascript(TabbarChromeSupport.edgeBlurScript(true, height), null);
    }

    private void configureNavbarScrollBehavior(PluginCall call) {
        if (Boolean.TRUE.equals(call.getBoolean("resetScrollCollapsed", false))) {
            setNavbarScrollCollapsed(false, false);
        }

        navbarScrollBehavior = NavbarScrollSupport.parseBehavior(call.getString("scrollBehavior"));
        Double threshold = call.getDouble("scrollThreshold");
        if (threshold != null) {
            navbarScrollThreshold = threshold.floatValue();
        }

        boolean observeScroll = NavbarScrollSupport.shouldObserveScroll(
            navbarScrollBehavior,
            navbarVisible,
            navbarLarge,
            navbarSearchVisible,
            navbarSearchHidesWhenCollapsed
        );
        // Hide/reveal is off, but a collapsing search row still needs the same samples.
        if (navbarScrollBehavior == NavbarScrollSupport.ScrollBehavior.NONE || !navbarVisible) {
            stopNavbarScrollObservation(true);
        }
        if (observeScroll) {
            startNavbarScrollObservation();
        }
    }

    private void startNavbarScrollObservation() {
        if (getBridge() == null || getBridge().getWebView() == null) {
            return;
        }
        String script =
            "(function(){" +
            "const plugin=window.Capacitor?.Plugins?.NativeNavigation;" +
            "if(!plugin?.reportNavbarScroll){return;}" +
            "const core=window.__capNativeNavigationScrollCore||(window.__capNativeNavigationScrollCore={samples:new WeakMap(),bound:new WeakSet()});" +
            "const readOffset=(target)=>{" +
            "const raw=target===window?window.scrollY:target.scrollTop;" +
            "const max=target===window?Math.max(0,document.documentElement.scrollHeight-window.innerHeight):Math.max(0,target.scrollHeight-target.clientHeight);" +
            "return Math.min(Math.max(0,raw),max);" +
            "};" +
            "const bind=(target)=>{" +
            "if(!target||core.bound.has(target)){return;}" +
            "core.bound.add(target);" +
            "target.addEventListener('scroll',()=>{" +
            "const offsetY=readOffset(target);" +
            "const previous=core.samples.get(target)??offsetY;" +
            "const deltaY=offsetY-previous;" +
            "core.samples.set(target,offsetY);" +
            "plugin.reportNavbarScroll({offsetY,deltaY});" +
            "},{passive:true});" +
            "};" +
            "bind(window);" +
            "bind(document.getElementById('app'));" +
            "document.querySelectorAll('[data-cap-native-navigation-scroll]').forEach((node)=>bind(node));" +
            "})();";
        getBridge().getWebView().evaluateJavascript(script, null);
    }

    private void stopNavbarScrollObservation(boolean resetCollapsed) {
        if (resetCollapsed) {
            setNavbarScrollCollapsed(false, false);
        }
    }

    private void handleNavbarScroll(float offsetY, float deltaY) {
        NavbarScrollSupport.ScrollAction action = NavbarScrollSupport.scrollAction(
            navbarScrollBehavior,
            offsetY,
            deltaY,
            navbarScrollThreshold,
            navbarScrollCollapsed
        );
        if (action == NavbarScrollSupport.ScrollAction.HIDE) {
            setNavbarScrollCollapsed(true, true);
        } else if (action == NavbarScrollSupport.ScrollAction.REVEAL) {
            setNavbarScrollCollapsed(false, true);
        }
    }

    private void setNavbarScrollCollapsed(boolean collapsed, boolean animated) {
        if (navbarScrollCollapsed == collapsed) {
            return;
        }
        navbarScrollCollapsed = collapsed;
        applyNavbarScrollCollapsedAppearance(animated);
        if (animated && !collapsed && navbarContainer != null) {
            navbarContainer.postDelayed(this::updateInsetsAndNotify, 220);
        } else {
            updateInsetsAndNotify();
        }
    }

    /** Navbar height under the status bar for a large title progress, in device pixels. */
    private int navbarBarHeight(float largeProgress) {
        return Math.round(dp((double) NavbarLargeTitleSupport.barHeightDp(largeProgress)));
    }

    private void setNavbarLargeProgress(float target, boolean animated) {
        if (navbarLargeAnimator != null) {
            navbarLargeAnimator.cancel();
            navbarLargeAnimator = null;
        }
        if (!animated || navbarLargeProgress == target) {
            navbarLargeProgress = target;
            applyNavbarLargeProgress();
            return;
        }
        ValueAnimator animator = ValueAnimator.ofFloat(navbarLargeProgress, target);
        animator.setDuration(NavbarLargeTitleSupport.ANIMATION_MS);
        animator.setInterpolator(new PathInterpolator(0.2f, 0f, 0f, 1f));
        animator.addUpdateListener((animation) -> {
            navbarLargeProgress = (float) animation.getAnimatedValue();
            applyNavbarLargeProgress();
            resizeNavbarContainer();
        });
        navbarLargeAnimator = animator;
        animator.start();
    }

    /** Animation frames only resize the navbar; the tabbar and insets keep their layout. */
    private void resizeNavbarContainer() {
        if (navbarContainer == null || !navbarVisible) {
            return;
        }
        ViewGroup.LayoutParams params = navbarContainer.getLayoutParams();
        if (params == null) {
            return;
        }
        params.height = nativeStatusBarInset() + (navbarScrollCollapsed ? 0 : navbarBarHeight(navbarLargeProgress) + navbarAccessoryHeight());
        navbarContainer.setLayoutParams(params);
        // Full layout places the search row once. These frames skip that path, so the row has to
        // follow the large title or it stays overlapped or clipped after the animation.
        if (navbarSearchField != null && navbarSearchField.getLayoutParams() instanceof ViewGroup.MarginLayoutParams) {
            ViewGroup.MarginLayoutParams searchParams = (ViewGroup.MarginLayoutParams) navbarSearchField.getLayoutParams();
            searchParams.topMargin = nativeStatusBarInset() + navbarBarHeight(navbarLargeProgress) + dp(8);
            navbarSearchField.setLayoutParams(searchParams);
        }
        if (navbarSegments != null && navbarSegments.getLayoutParams() instanceof ViewGroup.MarginLayoutParams) {
            ViewGroup.MarginLayoutParams segmentsParams = (ViewGroup.MarginLayoutParams) navbarSegments.getLayoutParams();
            segmentsParams.topMargin = nativeStatusBarInset() + navbarBarHeight(navbarLargeProgress) + navbarSearchHeight();
            navbarSegments.setLayoutParams(segmentsParams);
        }
        if (tabbarStyle.isSidebar()) {
            layoutTabbarContainer();
        }
    }

    private void applyNavbarLargeProgress() {
        if (toolbar == null || largeTitleView == null) {
            return;
        }
        float progress = navbarLargeProgress;
        largeTitleView.setAlpha(NavbarLargeTitleSupport.largeTitleAlpha(progress));
        largeTitleView.setTranslationY(-(1f - progress) * dp(NavbarLargeTitleSupport.LARGE_TITLE_ROW_DP) * 0.5f);
        largeTitleView.setVisibility(progress > 0f ? View.VISIBLE : View.INVISIBLE);
        float inlineAlpha = NavbarLargeTitleSupport.inlineTitleAlpha(progress);
        toolbar.setTitleTextColor(withAlpha(navbarForegroundColor, Math.round(Color.alpha(navbarForegroundColor) * inlineAlpha)));
    }

    private void applyNavbarScrollCollapsedAppearance(boolean animated) {
        if (navbarContainer == null) {
            return;
        }
        float hideDistance = navbarBarHeight(navbarLargeProgress) + navbarAccessoryHeight();
        if (animated) {
            navbarContainer
                .animate()
                .translationY(navbarScrollCollapsed ? -hideDistance : 0f)
                .alpha(navbarScrollCollapsed ? 0f : 1f)
                .setDuration(220)
                .start();
        } else {
            navbarContainer.setTranslationY(navbarScrollCollapsed ? -hideDistance : 0f);
            navbarContainer.setAlpha(navbarScrollCollapsed ? 0f : 1f);
        }
    }

    private JSObject currentInsets() {
        // View layout uses device pixels; CSS variables must be density-independent
        // or a 3x screen writes `192px` which CSS treats as 192 CSS px.
        // Insets follow the target title state so the page moves once, not on every animation frame.
        int navbarToolbar = navbarScrollCollapsed ? 0 : navbarBarHeight(navbarLarge ? 1f : 0f) + navbarAccessoryHeight();
        int top = navbarVisible ? statusBarInset() + navbarToolbar : 0;
        boolean sidebar = tabbarVisible && tabbarStyle.isSidebar();
        int rail = sidebar ? dp(TabbarLayoutSupport.SIDEBAR_WIDTH_DP) + dp(12) : 0;
        boolean layoutRtl = tabbar != null && tabbar.isLayoutRtl();
        int left = sidebar && layoutRtl ? rail : 0;
        int right = sidebar && !layoutRtl ? rail : 0;
        int bottom = sidebar
            ? navigationBarInset()
            : (tabbarVisible ? navigationBarInset() + dp(tabbarStyle.totalHeight()) + dp(tabbarStyle.bottomGap) : 0);
        JSObject insets = new JSObject();
        insets.put("top", cssPx(top));
        insets.put("right", cssPx(right));
        insets.put("bottom", cssPx(bottom));
        insets.put("left", cssPx(left));
        insets.put("navbarHeight", cssPx(top));
        insets.put("tabbarHeight", cssPx(sidebar ? rail : bottom));
        insets.put("systemTabbarHeight", cssPx(sidebar ? rail : bottom));
        insets.put("verticalBarEdge", JSONObject.NULL);
        insets.put("reservedRegions", new JSONArray());
        insets.put("hinge", JSONObject.NULL);
        return insets;
    }

    /** Converts a layout pixel value to CSS pixels for WebView CSS variables. */
    private int cssPx(int devicePx) {
        float density = getContext().getResources().getDisplayMetrics().density;
        if (density <= 0f) {
            return devicePx;
        }
        return Math.round(devicePx / density);
    }

    private JSObject insetsResult() {
        JSObject result = new JSObject();
        result.put("insets", currentInsets());
        return result;
    }

    private JSObject transitionEvent(String id, String direction, int duration) {
        JSObject event = new JSObject();
        event.put("id", id);
        event.put("direction", direction);
        event.put("duration", duration);
        return event;
    }

    private boolean isStationaryTransition(String direction) {
        return "tab".equals(direction) || "root".equals(direction) || "none".equals(direction);
    }

    private void prepareTransitionRootBackground(FrameLayout root, int surfaceColor) {
        activeTransitionRootBackground = root.getBackground();
        activeTransitionRootBackgroundCaptured = true;
        if (needsTransitionSurface(activeTransitionRootBackground)) {
            root.setBackgroundColor(surfaceColor);
        }
    }

    private void restoreTransitionRootBackground() {
        if (!activeTransitionRootBackgroundCaptured) {
            return;
        }
        FrameLayout root = contentRoot();
        if (root != null) {
            root.setBackground(activeTransitionRootBackground);
        }
        activeTransitionRootBackground = null;
        activeTransitionRootBackgroundCaptured = false;
    }

    private boolean needsTransitionSurface(Drawable background) {
        if (background == null) {
            return true;
        }
        if (background instanceof ColorDrawable) {
            return Color.alpha(((ColorDrawable) background).getColor()) < 255;
        }
        return false;
    }

    private int transitionSurfaceColor(View webView) {
        Drawable background = webView.getBackground();
        if (background instanceof ColorDrawable) {
            int color = ((ColorDrawable) background).getColor();
            if (Color.alpha(color) > 0) {
                return withAlpha(color, 255);
            }
        }
        int fallback = isNightMode() ? Color.rgb(18, 18, 18) : Color.WHITE;
        return dynamicColor(isNightMode() ? "system_neutral1_900" : "system_neutral1_50", fallback);
    }

    private FrameLayout contentRoot() {
        Activity activity = getActivity();
        return activity == null ? null : activity.findViewById(android.R.id.content);
    }

    private void enableEdgeToEdge() {
        Activity activity = getActivity();
        if (activity == null) {
            return;
        }
        Window window = activity.getWindow();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false);
        } else {
            window
                .getDecorView()
                .setSystemUiVisibility(
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                );
        }
    }

    /**
     * Native chrome is laid out inside {@code android.R.id.content}, so it only clears the part of a system bar
     * that overlaps that view. Capacitor's SystemBars plugin (default {@code insetsHandling: 'css'} without
     * {@code viewport-fit=cover}) may pad the decor view or, on API 35+ with WebView &lt; 140, pad the WebView's
     * parent while {@code android.R.id.content} stays at the window origin.
     */
    private int nativeStatusBarInset() {
        return InsetsOffsetSupport.adjustedSystemBarInset(rawStatusBarInset(), contentRootTopOffset());
    }

    private int nativeNavigationBarInset() {
        return InsetsOffsetSupport.adjustedSystemBarInset(rawNavigationBarInset(), contentRootBottomOffset());
    }

    /** JS/CSS insets also account for WebView position when SystemBars pads only the WebView parent. */
    private int statusBarInset() {
        return InsetsOffsetSupport.adjustedSystemBarInset(
            rawStatusBarInset(),
            InsetsOffsetSupport.effectiveTopOffset(contentRootTopOffset(), webViewTopOffset())
        );
    }

    private int navigationBarInset() {
        return InsetsOffsetSupport.adjustedSystemBarInset(
            rawNavigationBarInset(),
            InsetsOffsetSupport.effectiveBottomOffset(contentRootBottomOffset(), webViewBottomOffset())
        );
    }

    // API 30+ reads the currently visible bars so a hidden navigation bar (immersive mode) gives the space back.
    private int rawStatusBarInset() {
        WindowInsets insets = rootWindowInsets();
        if (insets != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                return insets.getInsets(WindowInsets.Type.statusBars() | WindowInsets.Type.displayCutout()).top;
            }
            return insets.getStableInsetTop();
        }
        return systemDimension("status_bar_height");
    }

    private int rawNavigationBarInset() {
        WindowInsets insets = rootWindowInsets();
        if (insets != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                return insets.getInsets(WindowInsets.Type.navigationBars()).bottom;
            }
            return insets.getStableInsetBottom();
        }
        return systemDimension("navigation_bar_height");
    }

    private WindowInsets rootWindowInsets() {
        Activity activity = getActivity();
        if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return null;
        }
        return activity.getWindow().getDecorView().getRootWindowInsets();
    }

    private int contentRootTopOffset() {
        FrameLayout root = contentRoot();
        if (root == null || !root.isLaidOut()) {
            return 0;
        }
        int[] location = new int[2];
        root.getLocationInWindow(location);
        return Math.max(0, location[1]);
    }

    private int contentRootBottomOffset() {
        FrameLayout root = contentRoot();
        Activity activity = getActivity();
        if (root == null || activity == null || !root.isLaidOut()) {
            return 0;
        }
        View decor = activity.getWindow().getDecorView();
        int[] location = new int[2];
        root.getLocationInWindow(location);
        return Math.max(0, decor.getHeight() - (location[1] + root.getHeight()));
    }

    private int webViewTopOffset() {
        View webView = getBridge() == null ? null : getBridge().getWebView();
        if (webView == null || !webView.isLaidOut()) {
            return 0;
        }
        int[] location = new int[2];
        webView.getLocationInWindow(location);
        return Math.max(0, location[1]);
    }

    private int webViewBottomOffset() {
        View webView = getBridge() == null ? null : getBridge().getWebView();
        Activity activity = getActivity();
        if (webView == null || activity == null || !webView.isLaidOut()) {
            return 0;
        }
        View decor = activity.getWindow().getDecorView();
        int[] location = new int[2];
        webView.getLocationInWindow(location);
        return Math.max(0, decor.getHeight() - (location[1] + webView.getHeight()));
    }

    private void watchContentRootBounds() {
        FrameLayout root = contentRoot();
        if (root == null) {
            return;
        }
        // SystemBars can add or drop its decor padding after load (for example once viewport-fit=cover is
        // detected), which moves the content root without a call into this plugin. Re-run layout when it moves.
        root.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
            if (top == oldTop && bottom == oldBottom && left == oldLeft && right == oldRight) {
                return;
            }
            if (navbarVisible || tabbarVisible) {
                view.post(this::updateInsetsAndNotify);
            }
        });
        // Showing or hiding a system bar changes the insets without necessarily moving the content root
        // (edge-to-edge apps). A zero-size probe hears every inset dispatch without replacing anyone's listener.
        View insetsProbe = new View(getContext());
        insetsProbe.setOnApplyWindowInsetsListener((view, insets) -> {
            if (navbarVisible || tabbarVisible) {
                view.post(this::updateInsetsAndNotify);
            }
            return insets;
        });
        root.addView(insetsProbe, new FrameLayout.LayoutParams(0, 0));
        attachWebViewBoundsWatcher();
    }

    private void attachWebViewBoundsWatcher() {
        if (webViewBoundsWatcherAttached || getBridge() == null || !isActiveForWebViewBoundsWatcher()) {
            return;
        }
        View webView = getBridge().getWebView();
        if (webView == null) {
            scheduleWebViewBoundsWatcherAttachRetry();
            return;
        }
        cancelPendingWebViewBoundsWatcherAttach();
        webViewBoundsWatcherAttachAttempts = 0;
        webViewBoundsWatcherAttached = true;
        webView.addOnLayoutChangeListener((view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) -> {
            if (top == oldTop && bottom == oldBottom && left == oldLeft && right == oldRight) {
                return;
            }
            if (
                !InsetsOffsetSupport.shouldUpdateOnWebViewBoundsChange(
                    navbarVisible,
                    tabbarVisible,
                    pullToRefresh.isEnabled()
                )
            ) {
                return;
            }
            if (navbarVisible || tabbarVisible) {
                view.post(this::updateInsetsAndNotify);
            } else {
                view.post(() -> pullToRefresh.setTopOffset(pullToRefreshTopPx()));
            }
        });
    }

    private boolean isActiveForWebViewBoundsWatcher() {
        Activity activity = getActivity();
        if (activity == null || activity.isFinishing()) {
            return false;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1 && activity.isDestroyed()) {
            return false;
        }
        return true;
    }

    private void scheduleWebViewBoundsWatcherAttachRetry() {
        if (!isActiveForWebViewBoundsWatcher()) {
            return;
        }
        if (webViewBoundsWatcherAttachAttempts >= WEB_VIEW_BOUNDS_WATCHER_MAX_ATTACH_ATTEMPTS) {
            return;
        }
        webViewBoundsWatcherAttachAttempts++;
        FrameLayout root = contentRoot();
        if (root == null) {
            return;
        }
        cancelPendingWebViewBoundsWatcherAttach();
        pendingWebViewBoundsWatcherAttach = this::attachWebViewBoundsWatcher;
        root.postDelayed(pendingWebViewBoundsWatcherAttach, WEB_VIEW_BOUNDS_WATCHER_RETRY_DELAY_MS);
    }

    private void cancelPendingWebViewBoundsWatcherAttach() {
        if (pendingWebViewBoundsWatcherAttach == null) {
            return;
        }
        FrameLayout root = contentRoot();
        if (root != null) {
            root.removeCallbacks(pendingWebViewBoundsWatcherAttach);
        }
        pendingWebViewBoundsWatcherAttach = null;
    }

    private int systemDimension(String name) {
        int id = getContext().getResources().getIdentifier(name, "dimen", "android");
        return id == 0 ? 0 : getContext().getResources().getDimensionPixelSize(id);
    }

    private int dp(int value) {
        return Math.round(value * getContext().getResources().getDisplayMetrics().density);
    }

    private float dp(double value) {
        return (float) (value * getContext().getResources().getDisplayMetrics().density);
    }

    private static final class GlassOptions {

        private static final String EFFECT_NONE = "none";
        private static final String EFFECT_LIQUID_GLASS = "liquidGlass";
        private static final double DEFAULT_BLUR_RADIUS_DP = 18d;
        private static final double DEFAULT_SURFACE_ALPHA = 0.62d;

        final String effect;
        final double blurRadiusDp;
        final double surfaceAlpha;

        GlassOptions(String effect, double blurRadiusDp, double surfaceAlpha) {
            this.effect = effect;
            this.blurRadiusDp = Math.max(0d, blurRadiusDp);
            this.surfaceAlpha = Math.max(0d, Math.min(1d, surfaceAlpha));
        }

        static GlassOptions defaults() {
            return new GlassOptions(EFFECT_NONE, DEFAULT_BLUR_RADIUS_DP, DEFAULT_SURFACE_ALPHA);
        }

        static GlassOptions from(JSObject raw, GlassOptions fallback) {
            GlassOptions base = fallback == null ? defaults() : fallback;
            if (raw == null) {
                return base;
            }

            String effect = raw.optString("effect", base.effect);
            if (!EFFECT_NONE.equals(effect) && !EFFECT_LIQUID_GLASS.equals(effect)) {
                effect = base.effect;
            }
            double blurRadiusDp = raw.has("blurRadius") ? raw.optDouble("blurRadius", base.blurRadiusDp) : base.blurRadiusDp;
            double surfaceAlpha = raw.has("surfaceAlpha") ? raw.optDouble("surfaceAlpha", base.surfaceAlpha) : base.surfaceAlpha;
            return new GlassOptions(effect, blurRadiusDp, surfaceAlpha);
        }

        boolean isLiquidGlass() {
            return EFFECT_LIQUID_GLASS.equals(effect);
        }
    }

    private void runOnUiThread(Runnable runnable) {
        Activity activity = getActivity();
        if (activity == null) {
            runnable.run();
            return;
        }
        activity.runOnUiThread(runnable);
    }
}
