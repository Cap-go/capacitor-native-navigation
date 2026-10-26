package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public class NativeNavigationIconMetricsTest {

    @Test
    public void readsDistinctWidthAndHeight() throws Exception {
        JSONObject icon = new JSONObject("{\"width\":96,\"height\":24}");
        assertEquals(96, NativeNavigationIconMetrics.widthDp(icon));
        assertEquals(24, NativeNavigationIconMetrics.heightDp(icon));
    }

    @Test
    public void defaultsToSquareTwentyFour() {
        assertEquals(24, NativeNavigationIconMetrics.widthDp(null));
        assertEquals(24, NativeNavigationIconMetrics.heightDp(null));
    }
}
