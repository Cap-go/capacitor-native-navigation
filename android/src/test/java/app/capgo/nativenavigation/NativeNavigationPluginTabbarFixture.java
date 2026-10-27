package app.capgo.nativenavigation;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.Drawable;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.appcompat.app.AppCompatActivity;
import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.List;
import org.robolectric.Robolectric;
import org.robolectric.RuntimeEnvironment;

/** Robolectric harness for {@link NativeNavigationPlugin} tab rendering (package-private production APIs). */
final class NativeNavigationPluginTabbarFixture {

    private static final String HOME_TITLE = "Home";

    private final NativeNavigationPlugin plugin;
    private final Context context;

    private NativeNavigationPluginTabbarFixture(NativeNavigationPlugin plugin, Context context) {
        this.plugin = plugin;
        this.context = context;
    }

    static NativeNavigationPluginTabbarFixture create() throws Exception {
        Context appContext = RuntimeEnvironment.getApplication();
        AppCompatActivity activity = Robolectric.buildActivity(AppCompatActivity.class).setup().get();
        NativeNavigationPlugin plugin = new NativeNavigationPlugin() {
            @Override
            public Context getContext() {
                return appContext;
            }

            @Override
            public AppCompatActivity getActivity() {
                return activity;
            }
        };
        setBooleanField(plugin, "tabbarDisableIndicator", true);
        return new NativeNavigationPluginTabbarFixture(plugin, appContext);
    }

    void renderLabeledHomeTabWithIcons() throws Exception {
        clearTabItems();
        addTabItem(HOME_TITLE, blueSquareIcon());
        setIntField(plugin, "selectedTabIndex", 0);
        invoke(plugin, "ensureTabbar");
        invoke(plugin, "renderTabbarItems", "labeled", true);
    }

    FrameLayout makeHomeTabButtonWithLabelRowHeightPx(int labelRowHeightPx) throws Exception {
        clearTabItems();
        addTabItem(HOME_TITLE, blueSquareIcon());
        setIntField(plugin, "tabLabelRowHeightPx", labelRowHeightPx);
        invoke(plugin, "ensureTabbar");
        Object item = getTabItems().get(0);
        return (FrameLayout) invoke(plugin, "makeTabButton", item, true, true, true, false);
    }

    int tabLabelRowHeightPx() throws Exception {
        return getIntField(plugin, "tabLabelRowHeightPx");
    }

    FrameLayout firstTabButton() throws Exception {
        View tabbar = (View) getField(plugin, "tabbar");
        if (tabbar == null || ((ViewGroup) tabbar).getChildCount() == 0) {
            throw new IllegalStateException("Tab bar has no rendered buttons");
        }
        return (FrameLayout) ((ViewGroup) tabbar).getChildAt(0);
    }

    int labelClipLayoutHeight(FrameLayout tabButton) throws Exception {
        Class<?> tabButtonClass = Class.forName("app.capgo.nativenavigation.NativeNavigationPlugin$TabButton");
        View labelClip = (View) getField(tabButton, tabButtonClass, "labelClip");
        if (labelClip == null) {
            throw new IllegalStateException("Expected label clip from makeTabButton with icons");
        }
        return labelClip.getLayoutParams().height;
    }

    void layoutTabButtonForScreenshot(FrameLayout button) {
        int width = dp(120);
        int height = dp(96);
        button.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        );
        button.layout(0, 0, width, height);
        button.setBackgroundColor(Color.WHITE);
    }

    private void clearTabItems() throws Exception {
        getTabItems().clear();
    }

    @SuppressWarnings("unchecked")
    private List<Object> getTabItems() throws Exception {
        return (List<Object>) getField(plugin, "tabItems");
    }

    private void addTabItem(String title, Drawable icon) throws Exception {
        Class<?> itemClass = Class.forName("app.capgo.nativenavigation.NativeNavigationPlugin$NativeTabItem");
        Constructor<?> constructor = itemClass.getDeclaredConstructor(
            String.class,
            String.class,
            Drawable.class,
            Drawable.class,
            String.class,
            boolean.class,
            boolean.class,
            int.class
        );
        constructor.setAccessible(true);
        Object item = constructor.newInstance("home", title, icon, null, null, true, false, 0);
        getTabItems().add(item);
    }

    private static Drawable blueSquareIcon() {
        return new ColorDrawable(Color.rgb(0, 122, 255));
    }

    private int dp(int value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }

    private static void setBooleanField(Object target, String name, boolean value) throws Exception {
        Field field = NativeNavigationPlugin.class.getDeclaredField(name);
        field.setAccessible(true);
        field.setBoolean(target, value);
    }

    private static void setIntField(Object target, String name, int value) throws Exception {
        Field field = NativeNavigationPlugin.class.getDeclaredField(name);
        field.setAccessible(true);
        field.setInt(target, value);
    }

    private static int getIntField(Object target, String name) throws Exception {
        Field field = NativeNavigationPlugin.class.getDeclaredField(name);
        field.setAccessible(true);
        return field.getInt(target);
    }

    private static Object getField(Object target, String name) throws Exception {
        Field field = NativeNavigationPlugin.class.getDeclaredField(name);
        field.setAccessible(true);
        return field.get(target);
    }

    private static Object getField(Object target, Class<?> declaringClass, String name) throws Exception {
        Field field = declaringClass.getDeclaredField(name);
        field.setAccessible(true);
        return field.get(target);
    }

    private static Object invoke(Object target, String name, Object... args) throws Exception {
        Class<?>[] types = new Class<?>[args.length];
        for (int index = 0; index < args.length; index++) {
            Object arg = args[index];
            if (arg instanceof Boolean) {
                types[index] = boolean.class;
            } else if (arg instanceof Integer) {
                types[index] = int.class;
            } else {
                types[index] = arg.getClass();
            }
        }
        Method method = NativeNavigationPlugin.class.getDeclaredMethod(name, types);
        method.setAccessible(true);
        return method.invoke(target, args);
    }
}
