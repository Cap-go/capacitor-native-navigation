package app.capgo.nativenavigation;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class SvgPathDataSupportTest {

    @Test
    public void normalizeSplitsCompactArcFlags() {
        String normalized = SvgPathDataSupport.normalizeArcFlagsInPathData("M0,0a5 5 0 0010 0");
        assertEquals("M 0 0 a 5 5 0 0 0 10 0", normalized);
    }

    @Test
    public void normalizeHandlesRepeatedArcSegments() {
        String normalized = SvgPathDataSupport.normalizeArcFlagsInPathData("a5 5 0 0010 0 5 5 0 0010 0");
        assertEquals("a 5 5 0 0 0 10 0 5 5 0 0 0 10 0", normalized);
    }

    @Test
    public void normalizeLeavesNonArcPathUnchanged() {
        String path = "M10 10 L20 20 C1 2 3 4 5 6";
        assertEquals(path, SvgPathDataSupport.normalizeArcFlagsInPathData(path));
    }

    @Test
    public void compactArcPathNormalizesSameAsSpacedPath() {
        String compact = "M0,0a5 5 0 0010 0";
        String spaced = "M0,0a5 5 0 0 0 10 0";
        String expected = "M 0 0 a 5 5 0 0 0 10 0";
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(spaced));
    }

    @Test
    public void compactArcFlagsWithSignOnCoordinate() {
        String compact = "M0,0a5 5 0 00-10 0";
        String spaced = "M0,0a5 5 0 0 0 -10 0";
        String expected = "M 0 0 a 5 5 0 0 0 -10 0";
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(spaced));
    }

    @Test
    public void compactArcFlagsWithDecimalCoordinates() {
        String compact = "M0,0a2.5 2.5 0 00.5.5";
        String spaced = "M0,0a2.5 2.5 0 0 0 .5 .5";
        String expected = "M 0 0 a 2.5 2.5 0 0 0 .5 .5";
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(spaced));
    }

    @Test
    public void compactArcFlagsWithScientificNotation() {
        String compact = "M0,0a1 1 0 001e1 0";
        String spaced = "M0,0a1 1 0 0 0 1e1 0";
        String expected = "M 0 0 a 1 1 0 0 0 1e1 0";
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(compact));
        assertEquals(expected, SvgPathDataSupport.normalizeArcFlagsInPathData(spaced));
    }
}
