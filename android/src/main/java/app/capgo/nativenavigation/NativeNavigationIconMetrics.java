package app.capgo.nativenavigation;

import org.json.JSONObject;

/** Resolved width and height for {@link NativeNavigationIcon} descriptors. */
public final class NativeNavigationIconMetrics {

    private NativeNavigationIconMetrics() {}

    public static int widthDp(JSONObject descriptor) {
        return sizeDp(descriptor, "width");
    }

    public static int heightDp(JSONObject descriptor) {
        return sizeDp(descriptor, "height");
    }

    private static int sizeDp(JSONObject descriptor, String key) {
        if (descriptor == null) {
            return 24;
        }
        double value = descriptor.optDouble(key, 24);
        return (int) Math.max(1, Math.round(value));
    }
}
