package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class SvgIconBitmapSizeTest {

    @Test
    public void preservesNonSquareAspectInPixelSize() {
        int[] size = SvgIconBitmapSize.pixelSize(2f, 96, 24);
        assertEquals(192, size[0]);
        assertEquals(48, size[1]);
    }
}
