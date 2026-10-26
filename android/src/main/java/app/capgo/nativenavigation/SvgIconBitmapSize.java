package app.capgo.nativenavigation;

/** Pixel size for rendered SVG toolbar/tab icons. */
public final class SvgIconBitmapSize {

    private SvgIconBitmapSize() {}

    public static int[] pixelSize(float density, int widthDp, int heightDp) {
        return new int[] {
            Math.max(1, Math.round(widthDp * density)),
            Math.max(1, Math.round(heightDp * density)),
        };
    }
}
