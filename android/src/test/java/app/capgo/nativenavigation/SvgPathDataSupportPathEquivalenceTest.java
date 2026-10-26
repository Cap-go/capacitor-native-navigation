package app.capgo.nativenavigation;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertNotNull;

import android.graphics.Path;

import androidx.core.graphics.PathParser;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(manifest = Config.NONE, sdk = 28)
public class SvgPathDataSupportPathEquivalenceTest {

    @Test
    public void normalizeLeavesSpacedArcPathEquivalent() {
        String spaced = "M0,0a5 5 0 0 0 10 0";
        String normalized = SvgPathDataSupport.normalizeArcFlagsInPathData(spaced);
        assertPathEquivalent(spaced, normalized);
    }

    @Test
    public void compactArcPathMatchesSpacedPathAfterNormalization() {
        String compact = "M0,0a5 5 0 0010 0";
        String spaced = "M0,0a5 5 0 0 0 10 0";
        String normalized = SvgPathDataSupport.normalizeArcFlagsInPathData(compact);
        assertPathEquivalent(spaced, normalized);
    }

    @Test
    public void compactArcFlagsWithSignOnCoordinateMatchesSpacedPath() {
        String compact = "M0,0a5 5 0 00-10 0";
        String spaced = "M0,0a5 5 0 0 0 -10 0";
        assertPathEquivalent(spaced, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
    }

    @Test
    public void compactArcFlagsWithDecimalCoordinatesMatchesSpacedPath() {
        String compact = "M0,0a2.5 2.5 0 00.5.5";
        String spaced = "M0,0a2.5 2.5 0 0 0 .5 .5";
        assertPathEquivalent(spaced, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
    }

    @Test
    public void compactArcFlagsWithScientificNotationMatchesSpacedPath() {
        String compact = "M0,0a1 1 0 001e1 0";
        String spaced = "M0,0a1 1 0 0 0 1e1 0";
        assertPathEquivalent(spaced, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
    }

    private static void assertPathEquivalent(String expectedPathData, String actualPathData) {
        Path expected = PathParser.createPathFromPathData(expectedPathData);
        Path actual = PathParser.createPathFromPathData(actualPathData);
        assertNotNull(expected);
        assertNotNull(actual);
        float[] expectedPoints = expected.approximate(0.5f);
        float[] actualPoints = actual.approximate(0.5f);
        assertArrayEquals(expectedPoints, actualPoints, 0.01f);
    }
}
