package app.capgo.capacitor.navigation;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import android.graphics.Bitmap;
import androidx.test.ext.junit.rules.ActivityScenarioRule;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject2;
import androidx.test.uiautomator.Until;
import java.io.File;
import java.io.FileOutputStream;
import org.junit.Rule;
import org.junit.Test;
import org.junit.runner.RunWith;

@RunWith(AndroidJUnit4.class)
public class FloatingTabbarScreenshotTest {

    private static final String SCREENSHOT_FILE = "floating-tabbar-screenshot.png";
    private static final long READY_TIMEOUT_MS = 60_000L;

    @Rule
    public ActivityScenarioRule<MainActivity> activityRule = new ActivityScenarioRule<>(MainActivity.class);

    @Test
    public void captureFloatingTabbarWithColorfulContent() throws Exception {
        UiDevice device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
        UiObject2 readyFlag = device.wait(Until.findObject(By.text("screenshot-ready")), READY_TIMEOUT_MS);
        assertNotNull(readyFlag);
        Thread.sleep(2_000);

        Bitmap bitmap = InstrumentationRegistry.getInstrumentation().getUiAutomation().takeScreenshot();
        assertNotNull(bitmap);

        File outputDir = new File(InstrumentationRegistry.getInstrumentation().getTargetContext().getFilesDir(), "Pictures");
        assertTrue(outputDir.exists() || outputDir.mkdirs());
        File output = new File(outputDir, SCREENSHOT_FILE);
        try (FileOutputStream stream = new FileOutputStream(output)) {
            assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream));
        }

        File marker = new File(outputDir, "floating-tabbar-screenshot.done");
        assertTrue(marker.createNewFile() || marker.exists());
    }
}
