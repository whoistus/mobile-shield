package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import org.junit.Test;

public class MobileShieldTest {
    @Test
    public void sdkVersionMatchesVersionFile() throws Exception {
        String expected = new String(
                Files.readAllBytes(Paths.get("..", "..", "VERSION")), StandardCharsets.UTF_8).trim();
        assertEquals(expected, MobileShield.getSdkVersion());
    }

    @Test
    public void nativeUnavailableOnJvmFallsBackToJavaConstant() {
        // The host JVM cannot load an Android .so; the facade must not throw.
        assertFalse(MobileShield.isNativeAvailable());
        assertEquals(BuildConfig.SDK_VERSION, MobileShield.getSdkVersion());
    }
}
