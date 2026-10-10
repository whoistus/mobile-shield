package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import io.mobileshield.config.Defaults;
import io.mobileshield.detectors.InstallerCheck;
import io.mobileshield.detectors.InstallerCheck.Source;
import java.util.Arrays;
import java.util.List;
import org.junit.Test;

public class InstallerCheckTest {
    private static final List<String> DEFAULTS = Defaults.INSTALLER_ALLOWLIST;

    @Test
    public void everyDefaultStoreIsTrusted() {
        assertEquals(10, DEFAULTS.size());
        for (String store : DEFAULTS) {
            assertEquals(store, Source.STORE, InstallerCheck.classify(store, DEFAULTS));
            assertEquals(0d, InstallerCheck.confidence(Source.STORE), 0);
        }
    }

    @Test
    public void adbOrMdmInstallWithNoInstallerIsSideload() {
        assertEquals(Source.SIDELOAD, InstallerCheck.classify(null, DEFAULTS));
    }

    @Test
    public void packageInstallersAreSideload() {
        for (String pi : new String[] {"com.google.android.packageinstaller", "com.android.packageinstaller", "com.miui.packageinstaller"}) {
            assertEquals(pi, Source.SIDELOAD, InstallerCheck.classify(pi, DEFAULTS));
        }
    }

    @Test
    public void unknownStoreIsUnlisted() {
        assertEquals(Source.UNLISTED, InstallerCheck.classify("com.example.store", DEFAULTS));
    }

    @Test
    public void sideloadAndUnlistedReportAtHalfConfidenceSoTheyNeverReachBlock() {
        for (Source s : new Source[] {Source.SIDELOAD, Source.UNLISTED}) {
            double c = InstallerCheck.confidence(s);
            assertEquals(0.5, c, 0);
            assertTrue(c < Defaults.BLOCK_THRESHOLD);
        }
    }

    @Test
    public void hostAllowlistOverridesDefaults() {
        List<String> custom = Arrays.asList("com.firebase.appdistribution", "com.corp.mdm");
        assertEquals(Source.STORE, InstallerCheck.classify("com.corp.mdm", custom));
        assertEquals(Source.UNLISTED, InstallerCheck.classify("com.android.vending", custom));
    }

    @Test
    public void allowlistedPackageInstallerStaysTrusted() {
        List<String> custom = Arrays.asList("com.google.android.packageinstaller");
        assertEquals(Source.STORE, InstallerCheck.classify("com.google.android.packageinstaller", custom));
    }

    @Test
    public void emptyAllowlistTreatsEveryInstallerAsUntrusted() {
        assertEquals(Source.UNLISTED, InstallerCheck.classify("com.android.vending", Arrays.<String>asList()));
    }
}
