package app.capgo.nativenavigation;

import android.util.Log;
import android.view.View;
import android.webkit.WebView;
import com.getcapacitor.JSObject;
import io.github.webview_native_ui.engine.NativeUIProjection;
import java.util.List;
import java.util.Map;

final class NativeNavigationWebUIEngine {
    static final String NAVBAR_SELECTOR = "#cap-native-navigation-navbar-slot";
    static final String TABBAR_SELECTOR = "#cap-native-navigation-tabbar-slot";

    private NativeUIProjection navbarProjection;
    private NativeUIProjection tabbarProjection;
    private NativeNavigationPlugin boundPlugin;
    private boolean active;

    boolean isActive() {
        return active;
    }

    void setActive(boolean enable, NativeNavigationPlugin plugin) {
        boundPlugin = plugin;
        if (!enable) {
            if (active) {
                active = false;
                teardown();
            }
            return;
        }
        if (active) {
            refreshChrome(plugin);
            return;
        }
        if (!install(plugin)) {
            active = false;
            teardown();
            return;
        }
        active = true;
        refreshChrome(plugin);
    }

    void forward(String eventName, JSObject data) {
        if (!active) {
            return;
        }
        if ("transitionStart".equals(eventName) || "transitionEnd".equals(eventName)) {
            return;
        }
        if (navbarProjection != null) {
            navbarProjection.receive(eventName, data);
        }
        if (tabbarProjection != null) {
            tabbarProjection.receive(eventName, data);
        }
    }

    void notifyChrome(String surface, boolean hidden) {
        if (!active || boundPlugin == null) {
            return;
        }
        JSObject payload = new JSObject();
        payload.put("surface", surface);
        String eventName = hidden ? "chromeHidden" : "chromeShown";
        boundPlugin.notifyWebUIChromeListeners(eventName, payload);
    }

    void prewireChannel(WebView webView) {
        if (webView == null) {
            return;
        }
        try {
            NativeNavigationWebUIEngineRunOnce.install(webView);
        } catch (RuntimeException error) {
            Log.w(NativeNavigationWebUIEngine.class.getSimpleName(), "Web UI engine channel prewire failed", error);
        }
    }

    void teardown() {
        if (navbarProjection != null) {
            navbarProjection.close();
            navbarProjection = null;
        }
        if (tabbarProjection != null) {
            tabbarProjection.close();
            tabbarProjection = null;
        }
    }

    private boolean install(NativeNavigationPlugin plugin) {
        WebView webView = plugin.getBridge().getWebView();
        if (webView == null) {
            return false;
        }
        if (!NativeNavigationWebUIEngineRunOnce.isInstalled()) {
            prewireChannel(webView);
        }
        if (!NativeNavigationWebUIEngineRunOnce.isInstalled()) {
            return false;
        }
        injectProjectionSlots(webView);
        if (navbarProjection == null) {
            navbarProjection = makeProjection(plugin, NAVBAR_SELECTOR, "navbar", plugin::getNavbarProjectionView);
        }
        if (tabbarProjection == null) {
            tabbarProjection = makeProjection(plugin, TABBAR_SELECTOR, "tabbar", plugin::getTabbarProjectionView);
        }
        if (navbarProjection == null || tabbarProjection == null) {
            return false;
        }
        return true;
    }

    private void refreshChrome(NativeNavigationPlugin plugin) {
        notifyChrome("navbar", !plugin.isNavbarProjectionVisible());
        notifyChrome("tabbar", !plugin.isTabbarProjectionVisible());
    }

    private NativeUIProjection makeProjection(
        NativeNavigationPlugin plugin, String selector, String surface, ProjectionViewProvider viewProvider) {
        try {
            NativeUIProjection.ReceiveListeners listeners =
                new NativeUIProjection.ReceiveListeners(
                    List.of("safeAreaChanged"),
                    new NativeUIProjection.ReceiveListeners.Projection(
                        List.of("chromeShown"), List.of(), List.of("chromeHidden")),
                    Map.of("surface", surface));
            return new NativeUIProjection(
                plugin.getActivity().getWindow(),
                plugin.getBridge().getWebView(),
                plugin.getPluginHandle().getId(),
                selector,
                listeners,
                () -> viewProvider.provide());
        } catch (RuntimeException error) {
            Log.e(NativeNavigationWebUIEngine.class.getSimpleName(), "Web UI engine projection failed", error);
            return null;
        }
    }

    private void injectProjectionSlots(WebView webView) {
        webView.evaluateJavascript(
            "(function(){if(globalThis.__capNativeNavigationProjectionSlots){return;}"
                + "const make=(id,placement)=>{if(document.getElementById(id)){return;}"
                + "const slot=document.createElement('div');slot.id=id;"
                + "slot.setAttribute('data-cap-native-navigation-projection-slot',placement);"
                + "slot.setAttribute('aria-hidden','true');"
                + "slot.style.cssText=placement==='top'"
                + "? 'position:fixed;left:0;right:0;top:0;pointer-events:none;z-index:0;"
                + "overflow:hidden;margin:0;padding:0;border:0;height:var(--cap-native-navbar-height, 0px)'"
                + ": 'position:fixed;left:0;right:0;bottom:0;pointer-events:none;z-index:0;"
                + "overflow:hidden;margin:0;padding:0;border:0;"
                + "height:max(var(--cap-native-tabbar-height, 0px), var(--cap-native-system-tabbar-height, 0px))';"
                + "document.documentElement.appendChild(slot);};"
                + "make('cap-native-navigation-navbar-slot','top');"
                + "make('cap-native-navigation-tabbar-slot','bottom');"
                + "globalThis.__capNativeNavigationProjectionSlots=true;})();",
            null);
    }

    @FunctionalInterface
    interface ProjectionViewProvider {
        View provide();
    }

    private static final class NativeNavigationWebUIEngineRunOnce {
        private static boolean installed;

        private NativeNavigationWebUIEngineRunOnce() {}

        static boolean isInstalled() {
            return installed;
        }

        static void install(WebView webView) {
            if (installed || webView == null) {
                return;
            }
            try {
                NativeUIProjection.install(webView);
                installed = true;
            } catch (RuntimeException error) {
                Log.w(
                    NativeNavigationWebUIEngine.class.getSimpleName(),
                    "Web UI engine channel prewire failed",
                    error);
            }
        }
    }
}