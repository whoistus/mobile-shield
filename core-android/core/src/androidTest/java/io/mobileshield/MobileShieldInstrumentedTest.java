package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;

/** On-device proof that libmobileshield.so loads and the version round-trips through JNI. */
@RunWith(AndroidJUnit4.class)
public class MobileShieldInstrumentedTest {
    @Test
    public void nativeLibraryLoadsAndVersionRoundTripsThroughJni() {
        String expected = InstrumentationRegistry.getArguments().getString("expectedVersion");
        assertTrue("libmobileshield.so failed to load", MobileShield.isNativeAvailable());
        assertEquals(expected, MobileShield.nativeVersion());
        assertEquals(expected, MobileShield.getSdkVersion());
    }
}
