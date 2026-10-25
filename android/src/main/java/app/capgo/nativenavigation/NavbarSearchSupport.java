package app.capgo.nativenavigation;

/** Height of the navbar search row (unit tested). */
public final class NavbarSearchSupport {

    public static final int ROW_HEIGHT_DP = 52;

    private NavbarSearchSupport() {}

    /**
     * @param hidesWhenCollapsed when the large title folds away, the row folds with it
     */
    public static int rowHeightDp(boolean visible, boolean hidesWhenCollapsed, boolean largeCollapsed) {
        if (!visible || (hidesWhenCollapsed && largeCollapsed)) {
            return 0;
        }
        return ROW_HEIGHT_DP;
    }

    /** A missing flag follows the large title: stacked search hides once that title collapses. */
    public static boolean hidesWhenCollapsed(Boolean requested, boolean largeTitle) {
        return requested == null ? largeTitle : requested;
    }
}
