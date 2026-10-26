package app.capgo.nativenavigation;

import org.json.JSONArray;
import org.json.JSONObject;

/** Android navbar toolbar placement helpers (left items vs navigation icon). */
public final class NavbarToolbarItemsSupport {

    private NavbarToolbarItemsSupport() {}

    /**
     * When {@code true}, the first left item with an icon should use the toolbar navigation slot
     * instead of the overflow menu.
     */
    public static boolean shouldPromoteLeadingLeftItemToNavigation(boolean backButtonVisible) {
        return !backButtonVisible;
    }

    public static int indexOfFirstLeftItemWithIcon(JSONArray items) {
        if (items == null) {
            return -1;
        }
        for (int index = 0; index < items.length(); index++) {
            JSONObject item = items.optJSONObject(index);
            if (item != null && hasRenderableIcon(item.optJSONObject("icon"))) {
                return index;
            }
        }
        return -1;
    }

    static boolean hasRenderableIcon(JSONObject icon) {
        if (icon == null) {
            return false;
        }
        if (!icon.optString("svg", "").isEmpty()) {
            return true;
        }
        JSONObject android = icon.optJSONObject("android");
        if (android != null) {
            if (!android.optString("svg", "").isEmpty()) {
                return true;
            }
            if (!android.optString("resource", "").isEmpty()) {
                return true;
            }
            if (!android.optString("image", "").isEmpty()) {
                return true;
            }
        }
        return !icon.optString("src", "").isEmpty();
    }
}
