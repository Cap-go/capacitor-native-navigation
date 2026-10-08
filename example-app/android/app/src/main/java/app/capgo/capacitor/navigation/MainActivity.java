package app.capgo.capacitor.navigation;

import android.os.Bundle;

import androidx.core.splashscreen.SplashScreen;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        if ("floating-tabbar".equals(BuildConfig.SCREENSHOT_MODE)) {
            SplashScreen splashScreen = SplashScreen.installSplashScreen(this);
            splashScreen.setKeepOnScreenCondition(() -> false);
        }
        super.onCreate(savedInstanceState);
    }
}
