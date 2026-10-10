package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import io.mobileshield.config.Defaults;
import io.mobileshield.detectors.EmulatorScorer;
import io.mobileshield.detectors.EmulatorScorer.Signals;
import org.junit.Test;

public class EmulatorScorerTest {
    private static final double BLOCK = Defaults.BLOCK_THRESHOLD;

    @Test
    public void cleanPhoneScoresZero() {
        Signals s = new Signals();
        assertEquals(0d, EmulatorScorer.confidence(s), 0);
    }

    @Test
    public void aospEmulatorReachesBlockThreshold() {
        Signals s = new Signals();
        s.qemuProps = true;
        s.qemuFiles = true;
        s.emulatorHardware = true;
        s.buildFieldHits = 4;
        assertEquals(4, EmulatorScorer.strongCount(s));
        assertTrue(EmulatorScorer.confidence(s) >= 0.95);
    }

    @Test
    public void twoStrongSignalsReachBlockThreshold() {
        Signals s = new Signals();
        s.emulatorHardware = true;
        s.qemuFiles = true;
        assertTrue(EmulatorScorer.confidence(s) >= BLOCK);
    }

    @Test
    public void oneStrongSignalNeverBlocks() {
        for (int which = 0; which < 4; which++) {
            Signals s = new Signals();
            s.qemuProps = which == 0;
            s.qemuFiles = which == 1;
            s.emulatorHardware = which == 2;
            s.buildFieldHits = which == 3 ? 2 : 0;
            assertEquals(1, EmulatorScorer.strongCount(s));
            assertTrue("signal " + which, EmulatorScorer.confidence(s) < BLOCK);
            assertTrue(EmulatorScorer.confidence(s) > 0);
        }
    }

    @Test
    public void oneStrongPlusManyWeakStaysBelowBlock() {
        Signals s = new Signals();
        s.qemuFiles = true;
        s.abiMismatch = true;
        s.noSensors = true;
        s.noTelephony = true;
        assertEquals(0.6, EmulatorScorer.confidence(s), 1e-9);
        assertTrue(EmulatorScorer.confidence(s) < BLOCK);
    }

    @Test
    public void whiteLabelTabletWithGenericBuildIsNotBlocked() {
        Signals s = new Signals();
        s.buildFieldHits = 1;
        s.noTelephony = true;
        s.noSensors = true;
        assertEquals(0, EmulatorScorer.strongCount(s));
        assertTrue(EmulatorScorer.confidence(s) < BLOCK);
    }

    @Test
    public void singleWeakSignalProducesNoEvent() {
        Signals s = new Signals();
        s.noTelephony = true;
        assertEquals(0d, EmulatorScorer.confidence(s), 0);
    }

    @Test
    public void buildFieldHitsCountsEmulatorImages() {
        assertEquals(5, EmulatorScorer.buildFieldHits(
                "generic/sdk_gphone_x86/generic:11/RSR1/1:userdebug/dev-keys", "sdk_gphone_x86",
                "Genymotion", "generic", "generic_x86", "sdk_gphone_x86"));
        assertEquals(0, EmulatorScorer.buildFieldHits(
                "samsung/dm1qxxx/dm1q:14/UP1A/1:user/release-keys", "SM-S911B", "samsung", "samsung", "dm1q", "dm1qxxx"));
    }

    @Test
    public void amazonFireTabletIsClean() {
        assertEquals(0, EmulatorScorer.buildFieldHits(
                "Amazon/karnak/karnak:11/RS8332/1:user/amz-keys", "KFRAWI", "Amazon", "Amazon", "karnak", "karnak"));
    }

    @Test
    public void nullBuildFieldsDoNotThrow() {
        assertEquals(0, EmulatorScorer.buildFieldHits(null, null, null, null, null, null));
    }
}
