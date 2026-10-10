package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import android.content.Context;
import android.util.Log;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import io.mobileshield.internal.NativeBridge;
import io.mobileshield.model.EnvironmentInfo;
import io.mobileshield.model.ThreatEvent;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import org.json.JSONObject;
import org.junit.BeforeClass;
import org.junit.Test;
import org.junit.runner.RunWith;

/** On-device proof that the native library loads, every detector runs, and one pass is fast. */
@RunWith(AndroidJUnit4.class)
public class SmokeInstrumentedTest {
    private static final String TAG = "MobileShieldSmoke";
    private static final int NATIVE_DETECTORS = 10;
    private static EnvironmentInfo env;

    private static Context context() {
        return InstrumentationRegistry.getInstrumentation().getTargetContext();
    }

    @BeforeClass
    public static void initOnce() throws Exception {
        env = MobileShield.init(context(), null);
    }

    @Test
    public void nativeLibraryLoadsAndVersionRoundTripsThroughJni() {
        String expected = InstrumentationRegistry.getArguments().getString("expectedVersion");
        assertTrue("libmobileshield.so failed to load", MobileShield.isNativeAvailable());
        assertEquals(expected, NativeBridge.version());
        assertEquals(expected, MobileShield.getSdkVersion());
    }

    @Test
    public void initReturnsAnAndroidEnvironmentWithoutAttestation() {
        assertNotNull(env);
        assertEquals("android", env.platform);
        assertTrue(env.attestationKinds.isEmpty());
        assertFalse(env.abi.isEmpty());
    }

    @Test
    public void nativeCatalogListsEveryNativeDetectorOnce() {
        NativeBridge.Entry[] catalog = NativeBridge.catalog();
        assertEquals(NATIVE_DETECTORS, catalog.length);
        Set<String> ids = new HashSet<>();
        for (NativeBridge.Entry e : catalog) assertTrue("duplicate " + e.id, ids.add(e.id));
        assertTrue(ids.contains("hooking.libIntegrity"));
        assertTrue(ids.contains("root.suPaths"));
    }

    @Test
    public void nativeChecksReturnOneResultPerDetectorAndHonourTheDisabledList() {
        float[] all = NativeBridge.runChecks(new String[0]);
        assertNotNull(all);
        assertEquals(NATIVE_DETECTORS, all.length);
        NativeBridge.Entry[] catalog = NativeBridge.catalog();
        String[] off = {catalog[0].id, catalog[1].id};
        float[] some = NativeBridge.runChecks(off);
        assertNotNull(some);
        assertTrue(some[0] < 0 && some[1] < 0);
    }

    @Test
    public void runChecksIsFastAndEventsAreWellFormed() {
        MobileShield.runChecks();  // warm-up: first run opens inotify and loads classes
        long worst = 0;
        long total = 0;
        List<ThreatEvent> last = null;
        final int runs = 5;
        for (int i = 0; i < runs; i++) {
            long start = System.nanoTime();
            last = MobileShield.runChecks();
            long ms = (System.nanoTime() - start) / 1_000_000;
            worst = Math.max(worst, ms);
            total += ms;
        }
        Log.i(TAG, "runChecks avg=" + (total / runs) + "ms worst=" + worst + "ms events=" + last.size());
        assertTrue("runChecks took " + worst + "ms", worst < 1500);
        for (ThreatEvent e : last) {
            assertTrue(e.confidence > 0 && e.confidence <= 1);
            assertEquals("android", e.platform);
            for (String v : e.details.values()) assertTrue("details must stay short and non-identifying: " + v, v.length() <= 64);
        }
    }

    @Test
    public void experimentalDetectorsNeverBlock() {
        for (ThreatEvent e : MobileShield.runChecks()) {
            if (io.mobileshield.config.Defaults.EXPERIMENTAL_IDS.contains(e.detectorId)) {
                assertEquals(e.detectorId, io.mobileshield.model.Action.REPORT, e.action);
            }
        }
    }

    @Test
    public void listenersReceiveEventsFromAnOnDemandPass() {
        final List<ThreatEvent> seen = new java.util.concurrent.CopyOnWriteArrayList<>();
        MobileShield.Listener listener = seen::add;
        MobileShield.stopMonitoring();
        MobileShield.addListener(listener);
        try {
            List<ThreatEvent> returned = MobileShield.runChecks();
            // A monitoring tick still in flight from another test may add events, so compare by id
            // rather than by count: every event of this pass must have reached the listener.
            java.util.Set<String> seenIds = new java.util.HashSet<>();
            for (ThreatEvent e : seen) seenIds.add(e.detectorId);
            for (ThreatEvent e : returned) assertTrue(e.detectorId, seenIds.contains(e.detectorId));
            assertTrue(seen.size() >= returned.size());
        } finally {
            MobileShield.removeListener(listener);
        }
    }

    @Test
    public void productionConfigWithoutAPinnedKeyIsRefused() throws Exception {
        try {
            MobileShield.updateConfig(new JSONObject().put("version", 1));
            fail("prod channel without CONFIG_PUBKEY must refuse runtime config");
        } catch (MobileShieldException e) {
            assertEquals(MobileShieldException.Reason.BootstrapMissing, e.reason);
        }
    }

    @Test
    public void monitoringStartsAndStopsCleanly() throws Exception {
        MobileShield.startMonitoring();
        MobileShield.startMonitoring();
        MobileShield.stopMonitoring();
        MobileShield.stopMonitoring();
    }

    @Test
    public void attestationIsReportedAsUnsupported() throws Exception {
        assertEquals("unsupported", MobileShield.attestEnrol("keystore", "nonce").getString("status"));
        assertEquals("unsupported", MobileShield.attestAssert("keystore", "nonce", "hash").getString("status"));
    }
}
