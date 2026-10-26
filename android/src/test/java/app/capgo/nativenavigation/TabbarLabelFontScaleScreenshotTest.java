package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Typeface;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.core.widget.TextViewCompat;
import java.io.File;
import java.io.FileOutputStream;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.annotation.GraphicsMode;

/**
 * Renders the tab label row at font scale 2.0 and writes PNGs when {@code generateTabbarLabelScreenshots=true}.
 * Matches the layout in {@link NativeNavigationPlugin#makeTabButton} (icon + clipped label row).
 */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35, qualifiers = "xxhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
public class TabbarLabelFontScaleScreenshotTest {

    private static final float FONT_SCALE = 2f;
    private static final int TAB_LABEL_TEXT_SP = 12;
    private static final int TAB_LABEL_MIN_HEIGHT_DP = 18;
    private static final int TAB_ICON_LABEL_GAP_DP = 2;
    private static final int TAB_CONTENT_PADDING_DP = 4;

    @Test
    public void tabLabelHeightUsesFontPaddingBounds() {
        applyFontScale(FONT_SCALE);
        float density = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().density;
        float scaledDensity = RuntimeEnvironment.getApplication().getResources().getDisplayMetrics().scaledDensity;
        int heightPx = TabbarLabelSupport.tabLabelHeightPx(density, scaledDensity);
        Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        paint.setTypeface(Typeface.DEFAULT_BOLD);
        paint.setTextSize(TAB_LABEL_TEXT_SP * scaledDensity);
        Paint.FontMetrics metrics = paint.getFontMetrics();
        int paddedLinePx = (int) Math.ceil(metrics.bottom - metrics.top);
        assertEquals(Math.max(Math.round(TAB_LABEL_MIN_HEIGHT_DP * density), paddedLinePx), heightPx);
        assertTrue(paddedLinePx >= (int) Math.ceil(metrics.descent - metrics.ascent));
    }

    @Test
    public void writeBeforeAndAfterScreenshotsWhenRequested() throws Exception {
        String enabled = System.getProperty("generateTabbarLabelScreenshots", System.getenv("GENERATE_TABBAR_LABEL_SCREENSHOTS"));
        if (!"true".equalsIgnoreCase(enabled)) {
            return;
        }
        applyFontScale(FONT_SCALE);
        File docs = resolveDocsDir();
        assertTrue(docs.isDirectory() || docs.mkdirs());
        writePng(
            new File(docs, "issue-93-android-tab-label-font-scale-before.png"),
            buildLabelRow(RuntimeEnvironment.getApplication(), false)
        );
        writePng(
            new File(docs, "issue-93-android-tab-label-font-scale-after.png"),
            buildLabelRow(RuntimeEnvironment.getApplication(), true)
        );
    }

    private static void applyFontScale(float fontScale) {
        Context context = RuntimeEnvironment.getApplication();
        Configuration configuration = new Configuration(context.getResources().getConfiguration());
        configuration.fontScale = fontScale;
        context.getResources().updateConfiguration(configuration, context.getResources().getDisplayMetrics());
    }

    private static View buildLabelRow(Context context, boolean useScaledLabelHeight) {
        float density = context.getResources().getDisplayMetrics().density;
        int minLabelPx = Math.round(TAB_LABEL_MIN_HEIGHT_DP * density);
        int labelRowHeight = useScaledLabelHeight
            ? TabbarLabelSupport.tabLabelHeightPx(
                density,
                context.getResources().getDisplayMetrics().scaledDensity
            )
            : minLabelPx;

        LinearLayout content = new LinearLayout(context);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setGravity(Gravity.CENTER);
        content.setBackgroundColor(Color.WHITE);
        content.setPadding(dp(context, TAB_CONTENT_PADDING_DP), dp(context, TAB_CONTENT_PADDING_DP), dp(context, TAB_CONTENT_PADDING_DP), dp(context, TAB_CONTENT_PADDING_DP));

        ImageView icon = new ImageView(context);
        icon.setBackgroundColor(Color.rgb(0, 122, 255));
        LinearLayout.LayoutParams imageParams = new LinearLayout.LayoutParams(dp(context, 24), dp(context, 24));
        imageParams.bottomMargin = dp(context, TAB_ICON_LABEL_GAP_DP);
        content.addView(icon, imageParams);

        TextView label = new TextView(context);
        label.setText("Home");
        label.setTextColor(Color.rgb(0, 122, 255));
        label.setTextSize(TAB_LABEL_TEXT_SP);
        label.setTypeface(Typeface.DEFAULT_BOLD);
        label.setGravity(Gravity.CENTER);
        label.setMaxLines(1);
        TextViewCompat.setAutoSizeTextTypeUniformWithConfiguration(label, 9, TAB_LABEL_TEXT_SP, 1, TypedValue.COMPLEX_UNIT_SP);

        FrameLayout labelClip = new FrameLayout(context);
        labelClip.addView(
            label,
            new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, labelRowHeight, Gravity.TOP)
        );
        content.addView(labelClip, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, labelRowHeight));

        int width = dp(context, 120);
        int height = dp(context, TAB_CONTENT_PADDING_DP) * 2 + dp(context, 24) + dp(context, TAB_ICON_LABEL_GAP_DP) + labelRowHeight;
        content.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        );
        content.layout(0, 0, width, height);
        return content;
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
