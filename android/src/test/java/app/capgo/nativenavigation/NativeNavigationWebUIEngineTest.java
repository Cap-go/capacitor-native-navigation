package app.capgo.nativenavigation;

import static org.junit.Assert.assertFalse;

import org.junit.Test;

public class NativeNavigationWebUIEngineTest {
    @Test
    public void startsInactive() {
        NativeNavigationWebUIEngine engine = new NativeNavigationWebUIEngine();
        assertFalse(engine.isActive());
    }
}