package app.capgo.nativenavigation;

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
import android.os.Build;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.view.ViewGroup;
import android.view.ViewOutlineProvider;
import android.view.Window;
import android.view.WindowInsets;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.appcompat.content.res.AppCompatResources;
import androidx.appcompat.widget.Toolbar;
import androidx.core.graphics.PathParser;
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
    private static final int DEFAULT_TRANSITION_MS = 350;
    private static final int MENU_ITEM_BASE = 10_000;

    private final NativeNavigation implementation = new NativeNavigation();
    private FrameLayout navbarContainer;
    private FrameLayout tabbarContainer;
    private Toolbar toolbar;
    private NativeTabbarLayout tabbar;
    private ImageView transitionSnapshot;
    private boolean enabled = true;
    private boolean navbarVisible = false;
    private boolean tabbarVisible = false;
    private String contentInsetMode = "css";
    private int defaultTransitionMs = DEFAULT_TRANSITION_MS;
    private int activeTransitionMs = DEFAULT_TRANSITION_MS;
    private int tintColor = Color.rgb(0, 122, 255);
    private int inactiveTintColor = Color.rgb(120, 126, 137);
    private int tabbarBackgroundColor = Color.argb(235, 255, 255, 255);
    private int badgeBackgroundColor = Color.rgb(255, 59, 48);
    private int badgeTextColor = Color.WHITE;
    private TabbarStyle tabbarStyle = TabbarStyle.defaults(Color.rgb(0, 122, 255));
    private String activeTransitionId;
    private String activeTransitionDirection = "forward";
    private RectF activeZoomSourceFrame;
    private float activeZoomCornerRadius = 0f;
    private final Map<Integer, String> menuActionIds = new HashMap<>();
    private final Map<Integer, String> menuActionTitles = new HashMap<>();
    private final Map<Integer, String> menuActionPlacements = new HashMap<>();
    private final List<NativeTabItem> tabItems = new ArrayList<>();
    private int selectedTabIndex = 0;

    @Override
    public void load() {
        Activity activity = getActivity();
        if (activity != null) {
            activity.runOnUiThread(this::enableEdgeToEdge);
        }
    }

    @PluginMethod
    public void configure(PluginCall call) {
        runOnUiThread(() -> {
            enabled = call.getBoolean("enabled", true);
            contentInsetMode = call.getString("contentInsetMode", contentInsetMode);
            Double duration = call.getDouble("animationDuration");
            if (duration != null) {
                defaultTransitionMs = Math.max(0, duration.intValue());
            }
            if (!enabled) {
                if (navbarContainer != null) {
                    navbarContainer.setVisibility(View.GONE);
                }
                if (tabbar != null) {
                    tabbar.setVisibility(View.GONE);
                }
                if (tabbarContainer != null) {
                    tabbarContainer.setVisibility(View.GONE);
                }
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
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            boolean hidden = call.getBoolean("hidden", false);
            navbarVisible = !hidden;
            if (hidden) {
                if (navbarContainer != null) {
                    navbarContainer.setVisibility(View.GONE);
                }
                updateInsetsAndNotify();
                call.resolve(insetsResult());
                return;
            }

            Toolbar nativeToolbar = ensureToolbar();
            nativeToolbar.setTitle(call.getString("title", ""));
            nativeToolbar.setSubtitle(call.getString("subtitle", null));
            nativeToolbar.getMenu().clear();
            menuActionIds.clear();
            menuActionTitles.clear();
            menuActionPlacements.clear();

            JSObject backButton = call.getObject("backButton", null);
            if (backButton != null && Boolean.TRUE.equals(backButton.getBool("visible"))) {
                nativeToolbar.setNavigationIcon(androidx.appcompat.R.drawable.abc_ic_ab_back_material);
                nativeToolbar.setNavigationContentDescription(backButton.getString("title", "Back"));
                nativeToolbar.setNavigationOnClickListener((v) -> notifyListeners("navbarBack", new JSObject().put("source", "navbar")));
            } else {
                nativeToolbar.setNavigationIcon(null);
                nativeToolbar.setNavigationOnClickListener(null);
                addToolbarItems(nativeToolbar, call.getArray("leftItems", new JSArray()), "left");
            }

            addToolbarItems(nativeToolbar, call.getArray("rightItems", new JSArray()), "right");
            JSObject colors = call.getObject("colors", new JSObject());
            applyToolbarColors(nativeToolbar, colors);
            navbarContainer.setVisibility(View.VISIBLE);
            layoutChrome();
            updateInsetsAndNotify();
            call.resolve(insetsResult());
        });
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
            tabbarVisible = !hidden;
            if (hidden) {
                if (tabbar != null) {
                    tabbar.setVisibility(View.GONE);
                }
                if (tabbarContainer != null) {
                    tabbarContainer.setVisibility(View.GONE);
                }
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
            JSONArray tabs = call.getArray("tabs", new JSArray());
            String selectedId = call.getString("selectedId", null);
            JSObject colors = call.getObject("colors", new JSObject());
            badgeBackgroundColor = colorOption(call, colors, "badgeBackgroundColor", "badgeBackground", Color.rgb(255, 59, 48));
            badgeTextColor = colorOption(call, colors, "badgeTextColor", "badgeText", Color.WHITE);

            for (int index = 0; index < tabs.length(); index++) {
                JSONObject tab = tabs.optJSONObject(index);
                if (tab == null) {
                    continue;
                }
                String id = tab.optString("id", "tab-" + index);
                String title = tab.optString("title", "");
                Drawable icon = icons ? iconFrom(tab.optJSONObject("icon")) : new ColorDrawable(Color.TRANSPARENT);
                Drawable selectedIcon = icons ? iconFrom(tab.optJSONObject("selectedIcon")) : null;
                String badge = tab.has("badge") ? String.valueOf(tab.opt("badge")) : null;
                tabItems.add(new NativeTabItem(id, title, icon, selectedIcon, badge, tab.optBoolean("enabled", true)));
                if (id.equals(selectedId)) {
                    selectedTabIndex = index;
                }
            }

            if (!tabItems.isEmpty() && (selectedTabIndex < 0 || selectedTabIndex >= tabItems.size())) {
                selectedTabIndex = 0;
            }

            applyTabbarColors(call, colors);
            tabbarStyle = makeTabbarStyle(call.getObject("style", new JSObject()));
            nativeTabbar.setTabbarStyle(tabbarStyle, tabbarBackgroundColor, centerTabIndex());
            renderTabbarItems(labelVisibilityMode, icons);
            if (tabbarContainer != null) {
                tabbarContainer.setVisibility(View.VISIBLE);
            }
            nativeTabbar.setVisibility(View.VISIBLE);
            layoutChrome();
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
            }

            Bitmap bitmap = Bitmap.createBitmap(webView.getWidth(), webView.getHeight(), Bitmap.Config.ARGB_8888);
            webView.draw(new Canvas(bitmap));
            if (zoomSourceRect != null) {
                Rect crop = bitmapCropRect(zoomSourceRect, bitmap);
                bitmap = Bitmap.createBitmap(bitmap, crop.left, crop.top, crop.width(), crop.height());
            }
            transitionSnapshot = new ImageView(getContext());
            transitionSnapshot.setImageBitmap(bitmap);
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

            webView.setTranslationX(startTranslation);
            webView.setAlpha("none".equals(direction) ? 1f : 0.01f);
            View snapshot = transitionSnapshot;
            JSObject event = transitionEvent(transitionId, direction, durationMs);
            Runnable finish = () -> {
                FrameLayout root = contentRoot();
                if (root != null && transitionSnapshot != null) {
                    root.removeView(transitionSnapshot);
                }
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
                    .alpha("none".equals(direction) ? 0f : 0.75f)
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

    private Toolbar ensureToolbar() {
        if (toolbar != null) {
            return toolbar;
        }
        FrameLayout root = contentRoot();
        navbarContainer = new FrameLayout(getContext());
        navbarContainer.setElevation(dp(8));
        toolbar = new Toolbar(getContext());
        toolbar.setPopupTheme(androidx.appcompat.R.style.ThemeOverlay_AppCompat_Light);
        toolbar.setOnMenuItemClickListener((item) -> {
            int itemId = item.getItemId();
            JSObject event = new JSObject();
            event.put("id", menuActionIds.get(itemId));
            event.put("title", menuActionTitles.get(itemId));
            event.put("placement", menuActionPlacements.get(itemId));
            notifyListeners("navbarItemTap", event);
            return true;
        });

        navbarContainer.addView(toolbar);
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
        tabbarContainer = new FrameLayout(getContext());
        tabbarContainer.setClipChildren(false);
        tabbarContainer.setClipToPadding(false);
        tabbarContainer.setElevation(dp(12));

        tabbar = new NativeTabbarLayout(getContext());
        tabbar.setClipChildren(false);
        tabbar.setClipToPadding(false);
        tabbar.setBackgroundColor(Color.TRANSPARENT);
        tabbarContainer.addView(
            tabbar,
            new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
        );
        if (root != null) {
            root.addView(tabbarContainer);
        } else {
            getActivity().addContentView(
                tabbarContainer,
                new ViewGroup.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(DEFAULT_TABBAR_DP))
            );
        }
        return tabbar;
    }

    private void renderTabbarItems(String labelVisibilityMode, boolean icons) {
        if (tabbar == null) {
            return;
        }
        tabbar.removeAllViews();
        int centerIndex = centerTabIndex();
        tabbar.setTabbarStyle(tabbarStyle, tabbarBackgroundColor, centerIndex);
        for (int index = 0; index < tabItems.size(); index++) {
            final int itemIndex = index;
            NativeTabItem item = tabItems.get(index);
            boolean selected = itemIndex == selectedTabIndex;
            boolean showLabel = shouldShowTabLabel(labelVisibilityMode, selected);
            FrameLayout button = makeTabButton(item, selected, showLabel, icons, itemIndex == centerIndex);
            button.setSelected(selected);
            button.setEnabled(item.enabled);
            button.setAlpha(item.enabled ? 1f : 0.38f);
            button.setOnClickListener((view) -> {
                if (!item.enabled) {
                    return;
                }
                selectedTabIndex = itemIndex;
                renderTabbarItems(labelVisibilityMode, icons);
                JSObject event = new JSObject();
                event.put("id", item.id);
                event.put("index", itemIndex);
                event.put("title", item.title);
                notifyListeners("tabSelect", event);
            });
            tabbar.addView(button, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
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
        FrameLayout button = new FrameLayout(getContext());
        button.setClipChildren(false);
        button.setClipToPadding(false);
        button.setForeground(selectableItemBackground());
        if (center) {
            GradientDrawable centerBackground = new GradientDrawable();
            centerBackground.setShape(GradientDrawable.OVAL);
            centerBackground.setColor(tabbarStyle.centerButtonColor);
            button.setBackground(centerBackground);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                button.setElevation(dp(10));
            }
        }

        if (!center && selected) {
            GradientDrawable selectedBackground = new GradientDrawable();
            selectedBackground.setShape(GradientDrawable.OVAL);
            selectedBackground.setColor(withAlpha(tintColor, 34));
            View selectedCircle = new View(getContext());
            selectedCircle.setBackground(selectedBackground);
            button.addView(selectedCircle, new FrameLayout.LayoutParams(dp(58), dp(58), Gravity.CENTER));
        }

        LinearLayout content = new LinearLayout(getContext());
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        content.setPadding(dp(4), dp(4), dp(4), dp(4));
        button.addView(content, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        Drawable currentIcon = selected && item.selectedIcon != null ? item.selectedIcon : item.icon;
        boolean labelVisible = center ? showLabel && (currentIcon == null || !icons) : showLabel;
        int itemColor = center ? tabbarStyle.centerButtonIconColor : (selected ? tintColor : inactiveTintColor);
        if (icons && currentIcon != null) {
            Drawable icon = currentIcon.mutate();
            icon.setTint(itemColor);
            ImageView image = new ImageView(getContext());
            image.setImageDrawable(icon);
            image.setColorFilter(itemColor);
            int imageSize = center ? dp(32) : dp(24);
            LinearLayout.LayoutParams imageParams = new LinearLayout.LayoutParams(imageSize, imageSize);
            imageParams.bottomMargin = labelVisible ? dp(2) : 0;
            content.addView(image, imageParams);
        }

        if (labelVisible) {
            TextView label = new TextView(getContext());
            label.setText(item.title);
            label.setTextColor(itemColor);
            label.setTextSize(12);
            label.setTypeface(Typeface.DEFAULT, selected ? Typeface.BOLD : Typeface.NORMAL);
            label.setGravity(Gravity.CENTER);
            label.setSingleLine(true);
            content.addView(label, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(18)));
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
        return button;
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

        NativeTabItem(String id, String title, Drawable icon, Drawable selectedIcon, String badge, boolean enabled) {
            this.id = id;
            this.title = title;
            this.icon = icon;
            this.selectedIcon = selectedIcon;
            this.badge = badge;
            this.enabled = enabled;
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
            int centerButtonIconColor
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
        }

        static TabbarStyle defaults(int tintColor) {
            return new TabbarStyle("floating", 64, 24, 430, 10, 32, null, 76, 38, tintColor, Color.WHITE);
        }

        boolean isCurve() {
            return "curve".equals(shape);
        }

        int barTop() {
            return isCurve() ? centerButtonLift : 0;
        }

        int totalHeight() {
            return height + barTop();
        }
    }

    private static final class NativeTabbarLayout extends FrameLayout {

        private final Paint backgroundPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private TabbarStyle style = TabbarStyle.defaults(Color.rgb(0, 122, 255));
        private int backgroundColor = Color.argb(235, 255, 255, 255);
        private int centerIndex = -1;

        NativeTabbarLayout(Context context) {
            super(context);
            setWillNotDraw(false);
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
        }

        @Override
        protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
            int width = MeasureSpec.getSize(widthMeasureSpec);
            int height = MeasureSpec.getSize(heightMeasureSpec);
            if (hasCenterButton()) {
                int barHeight = dp(style.height);
                int barTop = dp(style.barTop());
                int centerGap = Math.min(dp(style.centerButtonDiameter + 22), Math.round(width * 0.46f));
                int leftWidth = Math.max(0, Math.round(width / 2f - centerGap / 2f));
                int rightX = Math.min(width, Math.round(width / 2f + centerGap / 2f));
                measureRange(0, centerIndex, leftWidth, barHeight);
                measureChildExact(getChildAt(centerIndex), dp(style.centerButtonDiameter), dp(style.centerButtonDiameter));
                measureRange(centerIndex + 1, getChildCount(), width - rightX, barHeight);
                setMeasuredDimension(width, Math.max(height, barTop + barHeight));
                return;
            }

            int count = Math.max(getChildCount(), 1);
            int childWidth = width / count;
            for (int index = 0; index < getChildCount(); index++) {
                measureChildExact(getChildAt(index), childWidth, height);
            }
            setMeasuredDimension(width, height);
        }

        @Override
        protected void onLayout(boolean changed, int left, int top, int right, int bottom) {
            int width = right - left;
            int height = bottom - top;
            if (hasCenterButton()) {
                int barTop = dp(style.barTop());
                int barHeight = dp(style.height);
                int buttonDiameter = dp(style.centerButtonDiameter);
                int centerGap = Math.min(dp(style.centerButtonDiameter + 22), Math.round(width * 0.46f));
                int leftWidth = Math.max(0, Math.round(width / 2f - centerGap / 2f));
                int rightX = Math.min(width, Math.round(width / 2f + centerGap / 2f));
                View center = getChildAt(centerIndex);
                center.layout((width - buttonDiameter) / 2, 0, (width + buttonDiameter) / 2, buttonDiameter);
                layoutRange(0, centerIndex, 0, barTop, leftWidth, barHeight);
                layoutRange(centerIndex + 1, getChildCount(), rightX, barTop, width - rightX, barHeight);
                return;
            }

            layoutRange(0, getChildCount(), 0, 0, width, height);
        }

        private boolean hasCenterButton() {
            return style.isCurve() && centerIndex >= 0 && centerIndex < getChildCount();
        }

        private void measureRange(int start, int end, int width, int height) {
            int count = Math.max(0, end - start);
            if (count == 0) {
                return;
            }
            int childWidth = Math.max(0, width / count);
            for (int index = start; index < end; index++) {
                measureChildExact(getChildAt(index), childWidth, height);
            }
        }

        private void layoutRange(int start, int end, int left, int top, int width, int height) {
            int count = Math.max(0, end - start);
            if (count == 0) {
                return;
            }
            int childWidth = Math.max(0, width / count);
            for (int index = start; index < end; index++) {
                int childLeft = left + (index - start) * childWidth;
                getChildAt(index).layout(childLeft, top, childLeft + childWidth, top + height);
            }
        }

        private void measureChildExact(View child, int width, int height) {
            child.measure(
                MeasureSpec.makeMeasureSpec(Math.max(0, width), MeasureSpec.EXACTLY),
                MeasureSpec.makeMeasureSpec(Math.max(0, height), MeasureSpec.EXACTLY)
            );
        }

        private Path backgroundPath(int width, int height) {
            Path path = new Path();
            if (!style.isCurve()) {
                float radius = dp(style.cornerRadius);
                path.addRoundRect(new RectF(0, 0, width, height), radius, radius, Path.Direction.CW);
                return path;
            }
            float barTop = dp(style.barTop());
            float barHeight = dp(style.height);
            float cornerRadius = Math.min(dp(style.cornerRadius), barHeight / 2f);
            float centerX = width / 2f;
            float notchRadius = dp(style.centerButtonDiameter) / 2f + dp(7);
            float notchDepth = Math.min(barHeight * 0.78f, notchRadius);
            float leftShoulder = Math.max(cornerRadius, centerX - notchRadius);
            float rightShoulder = Math.min(width - cornerRadius, centerX + notchRadius);
            float control = notchDepth * 0.55228475f;
            RectF barRect = new RectF(0, barTop, width, barTop + barHeight);

            path.moveTo(barRect.left + cornerRadius, barRect.top);
            path.lineTo(leftShoulder, barRect.top);
            path.cubicTo(
                leftShoulder,
                barRect.top + control,
                centerX - control,
                barRect.top + notchDepth,
                centerX,
                barRect.top + notchDepth
            );
            path.cubicTo(centerX + control, barRect.top + notchDepth, rightShoulder, barRect.top + control, rightShoulder, barRect.top);
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
            int sizePx = Math.max(1, Math.round(iconSizeDp * resources.getDisplayMetrics().density));
            Bitmap bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(bitmap);
            RectF viewBox = viewBox(svg, iconSizeDp);
            canvas.scale(sizePx / Math.max(viewBox.width(), 1f), sizePx / Math.max(viewBox.height(), 1f));
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
            drawable.setBounds(0, 0, sizePx, sizePx);
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
                return PathParser.createPathFromPathData(data);
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

        private static RectF viewBox(String svg, int iconSizeDp) {
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
                width = iconSizeDp;
                height = iconSizeDp;
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
        int foreground = parseColor(colors.getString("foreground", null), foregroundFallback);
        tintColor = tint;
        nativeToolbar.setTitleTextColor(foreground);
        nativeToolbar.setSubtitleTextColor(withAlpha(foreground, 190));
        Drawable navigationIcon = nativeToolbar.getNavigationIcon();
        if (navigationIcon != null) {
            Drawable tintedIcon = navigationIcon.mutate();
            tintedIcon.setTint(tint);
            nativeToolbar.setNavigationIcon(tintedIcon);
        }
        if (navbarContainer != null) {
            navbarContainer.setBackgroundColor(background);
        }
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
        int centerButtonDiameter = Math.max(styleDimension(rawStyle, "centerButtonDiameter", 76), 44);
        int height = Math.max(styleDimension(rawStyle, "height", curve ? 76 : DEFAULT_TABBAR_DP), 44);
        int centerButtonLift = Math.max(styleDimension(rawStyle, "centerButtonLift", centerButtonDiameter / 2), 0);
        int bottomGap = Math.max(styleDimension(rawStyle, "bottomGap", curve ? 0 : 10), 0);
        int horizontalMargin = Math.max(styleDimension(rawStyle, "horizontalMargin", curve ? 0 : 24), 0);
        int maxWidth = Math.max(styleDimension(rawStyle, "maxWidth", curve ? 0 : 430), 0);
        int cornerRadius = Math.max(styleDimension(rawStyle, "cornerRadius", curve ? 24 : height / 2), 0);
        int centerButtonColor = parseColor(rawStyle.getString("centerButtonColor", null), tintColor);
        int centerButtonIconColor = parseColor(rawStyle.getString("centerButtonIconColor", null), Color.WHITE);
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
            centerButtonIconColor
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
            ? withAlpha(dynamicColor(isNightMode() ? "system_neutral1_900" : "system_neutral1_50", Color.WHITE), 245)
            : Color.argb(235, 255, 255, 255);
        tintColor = parseColor(colors.getString("tint", null), tintFallback);
        inactiveTintColor = parseColor(colors.getString("inactiveTint", null), inactiveFallback);
        tabbarBackgroundColor = parseColor(colors.getString("background", null), backgroundFallback);
        if (tabbar != null) {
            tabbar.setTabbarStyle(tabbarStyle, tabbarBackgroundColor, centerTabIndex());
        }
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

    private void layoutChrome() {
        FrameLayout root = contentRoot();
        if (root == null) {
            return;
        }
        int status = statusBarInset();
        int bottom = navigationBarInset();
        int navbarHeight = navbarVisible ? status + dp(DEFAULT_NAVBAR_DP) : 0;
        int tabbarHeight = dp(tabbarStyle.totalHeight());
        int tabbarBottomMargin = tabbarVisible ? bottom + dp(tabbarStyle.bottomGap) : bottom;

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
        }

        if (tabbarContainer != null) {
            int rootWidth = root.getWidth() > 0 ? root.getWidth() : Resources.getSystem().getDisplayMetrics().widthPixels;
            int availableWidth = Math.max(0, rootWidth - dp(tabbarStyle.horizontalMargin) * 2);
            int maxWidth = tabbarStyle.maxWidth > 0 ? dp(tabbarStyle.maxWidth) : availableWidth;
            int tabbarWidth = Math.min(availableWidth, maxWidth);
            FrameLayout.LayoutParams tabbarContainerParams = new FrameLayout.LayoutParams(
                tabbarWidth,
                tabbarHeight,
                Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL
            );
            tabbarContainerParams.bottomMargin = tabbarBottomMargin;
            tabbarContainer.setLayoutParams(tabbarContainerParams);
        }

        if (tabbar != null) {
            FrameLayout.LayoutParams tabbarParams = new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            );
            tabbar.setLayoutParams(tabbarParams);
            tabbar.setPadding(0, 0, 0, 0);
        }

        bringChromeToFront();
    }

    private void bringChromeToFront() {
        if (navbarContainer != null) {
            navbarContainer.bringToFront();
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
            "window.dispatchEvent(new CustomEvent('capNativeNavigation:safeAreaChanged',{detail:{insets:" +
            insets.toString() +
            "}}));" +
            "})();";
        getBridge().getWebView().evaluateJavascript(script, null);
    }

    private JSObject currentInsets() {
        int top = navbarVisible ? statusBarInset() + dp(DEFAULT_NAVBAR_DP) : 0;
        int bottom = tabbarVisible ? navigationBarInset() + dp(tabbarStyle.totalHeight()) + dp(tabbarStyle.bottomGap) : 0;
        JSObject insets = new JSObject();
        insets.put("top", top);
        insets.put("right", 0);
        insets.put("bottom", bottom);
        insets.put("left", 0);
        insets.put("navbarHeight", top);
        insets.put("tabbarHeight", bottom);
        return insets;
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

    private int statusBarInset() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            WindowInsets insets = getActivity().getWindow().getDecorView().getRootWindowInsets();
            if (insets != null) {
                return insets.getStableInsetTop();
            }
        }
        return systemDimension("status_bar_height");
    }

    private int navigationBarInset() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            WindowInsets insets = getActivity().getWindow().getDecorView().getRootWindowInsets();
            if (insets != null) {
                return insets.getStableInsetBottom();
            }
        }
        return systemDimension("navigation_bar_height");
    }

    private int systemDimension(String name) {
        int id = getContext().getResources().getIdentifier(name, "dimen", "android");
        return id == 0 ? 0 : getContext().getResources().getDimensionPixelSize(id);
    }

    private int dp(int value) {
        return Math.round(value * getContext().getResources().getDisplayMetrics().density);
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
