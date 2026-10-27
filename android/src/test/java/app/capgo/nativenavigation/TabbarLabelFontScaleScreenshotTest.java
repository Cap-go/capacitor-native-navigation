package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.graphics.Paint;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Typeface;
import android.view.View;
import android.widget.FrameLayout;
import java.io.File;
import java.io.FileOutputStream;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;

/**
 * Renders tab labels at font scale 2.0 and writes PNGs when {@code generateTabbarLabelScreenshots=true}.
 * Uses {@link NativeNavigationPlugin#renderTabbarItems} / {@link NativeNavigationPlugin#makeTabButton} for the after capture.
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35, qualifiers = "xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
public class TabbarLabelFontScaleScreenshotTest {

    private static final float FONT_SCALE = 2f;
    private static final int TAB_LABEL_TEXT_SP = 12;
    private static final int TAB_LABEL_MIN_HEIGHT_DP = 18;
    @Test
    public void renderTabbarItemsAppliesTabLabelRowHeightPxToLabelClip() throws Exception {
        applyFontScale(FONT_SCALE);
        NativeNavigationPluginTabbarFixture fixture = NativeNavigationPluginTabbarFixture.create();
        fixture.renderLabeledHomeTabWithIcons();
        float density = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().density;
        float scaledDensity = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().scaledDensity;
        int expected = TabbarLabelSupport.tabLabelHeightPxForTitle("Home", density, scaledDensity, true);
        assertEquals(expected, fixture.tabLabelRowHeightPx());
        assertEquals(expected, fixture.labelClipLayoutHeight(fixture.firstTabButton()));
    }

    @Test
    public void tabLabelHeightUsesFontPaddingBounds() {
        applyFontScale(FONT_SCALE);
        float density = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().density;
        float scaledDensity = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().scaledDensity;
        int heightPx = TabbarLabelSupport.tabLabelHeightPx(density, scaledDensity);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setTypeface(Typeface.DEFAULT_BOLD);
        paint.setTextSize(TAB_LABEL_TEXT_SP * scaledDensity);
        Paint.FontMetricsInt metrics = paint.getFontMetricsInt();
        int paddedLinePx = metrics.bottom - metrics.top;
        assertEquals(Math.max(Math.round(TAB_LABEL_MIN_HEIGHT_DP * density), paddedLinePx), heightPx);
        Paint.FontMetrics floatMetrics = paint.getFontMetrics();
        assertTrue(paddedLinePx >= (int) Math.ceil(floatMetrics.descent - floatMetrics.ascent));
    }

    @Test
    public void writeBeforeAndAfterScreenshotsWhenRequested() throws Exception {
        String enabled = System.getProperty("generateTabbarLabelScreenshots", System.getenv("GENERATE_TABBAR_LABEL_SCREENSHOTS"));
        if (!"true".equalsIgnoreCase(enabled)) {
            return;
        }
        applyFontScale(FONT_SCALE);
        Context context = RuntimeEnvironment.getApplication();
        float density = context.getResources().getDisplayMetrics().density;
        int legacyLabelRowPx = Math.round(TAB_LABEL_MIN_HEIGHT_DP * density);
        NativeNavigationPluginTabbarFixture fixture = NativeNavigationPluginTabbarFixture.create();
        FrameLayout beforeButton = fixture.makeHomeTabButtonWithLabelRowHeightPx(legacyLabelRowPx);
        fixture.layoutTabButtonForScreenshot(beforeButton);
        fixture.renderLabeledHomeTabWithIcons();
        FrameLayout afterButton = fixture.firstTabButton();
        fixture.layoutTabButtonForScreenshot(afterButton);
        File docs = resolveDocsDir();
        assertTrue(docs.isDirectory() || docs.mkdirs());
        writePng(new File(docs, "issue-93-android-tab-label-font-scale-before.png"), beforeButton);
        writePng(new File(docs, "issue-93-android-tab-label-font-scale-after.png"), afterButton);
    }

    private static void applyFontScale(float fontScale) {
        Context context = RuntimeEnvironment.getApplication();
        Configuration configuration = new Configuration(context.getResources().getConfiguration());
        configuration.fontScale = fontScale;
        context.getResources().updateConfiguration(configuration, context.getResources().getDisplayMetrics());
    }

    private static File resolveDocsDir() {
        File dir = new File(System.getProperty("user.dir"));
        while (dir != null) {
            if (new File(dir, "package.json").isFile() && new File(dir, "android").isDirectory()) {
                return new File(dir, "docs");
            }
            dir = dir.getParentFile();
        }
        throw new IllegalStateException("Could not locate repository docs directory");
    }

    private static int dp(Context context, int value) {
        return Math.round(value * context.getResources().getDisplayMetrics().density);
    }

    private static void writePng(File output, View view) throws Exception {
        Bitmap bitmap = Bitmap.createBitmap(view.getWidth(), view.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        view.draw(canvas);
        File parent = output.getParentFile();
        assertTrue(parent != null && (parent.exists() || parent.mkdirs()));
        try (FileOutputStream stream = new FileOutputStream(output)) {
            assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream));
        }
    }
}
