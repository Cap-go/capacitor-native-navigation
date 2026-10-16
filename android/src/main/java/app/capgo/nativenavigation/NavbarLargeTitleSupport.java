package app.capgo.nativenavigation;

/**
 * Large title geometry for the Android navbar. Progress runs from 0 (inline title in the
 * toolbar row) to 1 (large title in its own row under the toolbar), like an iOS large title.
 */
public final class NavbarLargeTitleSupport {

    /** Toolbar row height, matching the default Android navbar. */
    public static final int TOOLBAR_DP = 56;
    /** Extra row for the large title. iOS adds 52pt (44 to 96); Android uses the same row. */
    public static final int LARGE_TITLE_ROW_DP = 52;
    public static final int LARGE_TITLE_TEXT_SP = 32;
    public static final int LARGE_TITLE_BOTTOM_PADDING_DP = 6;
    public static final int ANIMATION_MS = 220;

    private NavbarLargeTitleSupport() {}

    /** Navbar height below the status bar, in dp, for a large title progress. */
    public static float barHeightDp(float progress) {
        return TOOLBAR_DP + LARGE_TITLE_ROW_DP * clamp(progress);
    }

    /** The large title fades out over the first half of the collapse so both titles never overlap. */
    public static float largeTitleAlpha(float progress) {
        return clamp(progress * 2f - 1f);
    }

    /** The inline toolbar title fades in over the second half of the collapse. */
    public static float inlineTitleAlpha(float progress) {
        return clamp(1f - progress * 2f);
    }

    /**
     * Animate only a collapse or expand of the same visible header. A new title is a new page;
     * the page transition already animates, so the header snaps to its new state.
     */
    public static boolean shouldAnimate(boolean wasVisible, String previousTitle, String title, boolean wasLarge, boolean large) {
        if (!wasVisible || wasLarge == large) {
            return false;
        }
        return previousTitle == null ? title == null : previousTitle.equals(title);
    }

    private static float clamp(float value) {
        return Math.max(0f, Math.min(1f, value));
    }
}
