package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.content.Context;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import io.mobileshield.detectors.InstallerCheck;
import io.mobileshield.env.EnvironmentProbe;
import io.mobileshield.model.EnvironmentInfo;
import org.junit.Test;
import org.junit.runner.RunWith;

/** GMS/HMS probing must work on AOSP (no GMS), Play and Huawei-style images without any GMS dependency. */
@RunWith(AndroidJUnit4.class)
public class EnvironmentProbeTest {
    private final Context context = InstrumentationRegistry.getInstrumentation().getTargetContext();

    private boolean hasPackage(String name) {
        try {
            context.getPackageManager().getPackageInfo(name, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        }
    }

    @Test
    public void probeDescribesTheDevice() {
        EnvironmentInfo info = EnvironmentProbe.probe(context, "9.9.9");
        assertEquals("9.9.9", info.sdkVersion);
        assertEquals("android", info.platform);
        assertEquals(Build.VERSION.RELEASE, info.osVersion);
        assertEquals(Build.SUPPORTED_ABIS[0], info.abi);
        assertTrue("androidTest APKs are debuggable", info.isDebuggable);
        assertTrue(info.attestationKinds.isEmpty());
    }

    @Test
    public void installedFlagsMatchThePackageManager() {
        assertEquals(hasPackage("com.google.android.gms"), EnvironmentProbe.gmsInstalled(context));
        assertEquals(hasPackage("com.huawei.hwid"), EnvironmentProbe.hmsInstalled(context));
        assertEquals(EnvironmentProbe.hmsInstalled(context), EnvironmentProbe.probe(context, "x").hmsAvailable);
    }

    @Test
    public void gmsAvailableNeedsBothThePackageAndTheClientApi() {
        EnvironmentInfo info = EnvironmentProbe.probe(context, "x");
        assertEquals(EnvironmentProbe.gmsInstalled(context) && EnvironmentProbe.gmsApiOnClasspath(), info.gmsAvailable);
    }

    @Test
    public void providerUsableImpliesInstalledAndNeverThrowsWithoutTheClientApi() {
        boolean usable = EnvironmentProbe.gmsProviderUsable(context);
        if (usable) assertTrue(EnvironmentProbe.gmsInstalled(context));
        if (!EnvironmentProbe.gmsApiOnClasspath()) assertFalse(usable);
    }

    @Test
    public void installerMatchesTheInstallerCheck() {
        assertEquals(InstallerCheck.installerOf(context), EnvironmentProbe.probe(context, "x").installer);
    }

    @Test
    public void probeIsIdempotent() {
        assertEquals(EnvironmentProbe.probe(context, "x").toJson().toString(), EnvironmentProbe.probe(context, "x").toJson().toString());
    }
}
