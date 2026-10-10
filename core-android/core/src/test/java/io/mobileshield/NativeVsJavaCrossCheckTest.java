package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import io.mobileshield.detectors.NativeVsJavaCrossCheck.Readings;
import io.mobileshield.detectors.NativeVsJavaCrossCheck;
import java.util.Arrays;
import java.util.Collections;
import org.junit.Test;

public class NativeVsJavaCrossCheckTest {
    private static final String DIR = "/data/app/~~x/io.example-y";

    private static Readings r(boolean su, int tracer, String version, String dir) {
        return new Readings(su, tracer, version, dir);
    }

    @Test
    public void identicalReadingsAgree() {
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, 0, "1.0", DIR), r(false, 0, "1.0", DIR)).isEmpty());
    }

    @Test
    public void suHiddenFromJavaOnlyIsFlagged() {
        assertEquals(Collections.singletonList("su"),
                NativeVsJavaCrossCheck.disagreements(r(true, 0, "1.0", DIR), r(false, 0, "1.0", DIR)));
    }

    @Test
    public void suHiddenFromNativeOnlyIsFlagged() {
        assertEquals(Collections.singletonList("su"),
                NativeVsJavaCrossCheck.disagreements(r(false, 0, "1.0", DIR), r(true, 0, "1.0", DIR)));
    }

    @Test
    public void tracerPidDisagreementIsFlaggedButUnreadableIsNot() {
        assertEquals(Collections.singletonList("tracerPid"),
                NativeVsJavaCrossCheck.disagreements(r(false, 123, "1.0", DIR), r(false, 0, "1.0", DIR)));
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, -1, "1.0", DIR), r(false, 0, "1.0", DIR)).isEmpty());
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, 0, "1.0", DIR), r(false, -1, "1.0", DIR)).isEmpty());
    }

    @Test
    public void differentTracerPidsBothNonZeroAgree() {
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, 7, "1.0", DIR), r(false, 9, "1.0", DIR)).isEmpty());
    }

    @Test
    public void swappedNativeLibraryVersionIsFlagged() {
        assertEquals(Collections.singletonList("version"),
                NativeVsJavaCrossCheck.disagreements(r(false, 0, "0.9", DIR), r(false, 0, "1.0", DIR)));
    }

    @Test
    public void unknownNativeVersionIsNotEvidence() {
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, 0, null, DIR), r(false, 0, "1.0", DIR)).isEmpty());
    }

    @Test
    public void relocatedApkIsFlaggedButUnmappedApkIsNot() {
        assertEquals(Collections.singletonList("apkDir"),
                NativeVsJavaCrossCheck.disagreements(r(false, 0, "1.0", "/data/app/other"), r(false, 0, "1.0", DIR)));
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, 0, "1.0", ""), r(false, 0, "1.0", DIR)).isEmpty());
        assertTrue(NativeVsJavaCrossCheck.disagreements(r(false, 0, "1.0", DIR), r(false, 0, "1.0", null)).isEmpty());
    }

    @Test
    public void everyDisagreementIsListed() {
        assertEquals(Arrays.asList("su", "tracerPid", "version", "apkDir"),
                NativeVsJavaCrossCheck.disagreements(r(true, 5, "0.9", "/a"), r(false, 0, "1.0", "/b")));
    }
}
