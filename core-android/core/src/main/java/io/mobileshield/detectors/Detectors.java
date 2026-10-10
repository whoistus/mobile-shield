package io.mobileshield.detectors;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/** Java-side detector registry. Native detectors are registered in cpp/detectors/Registry.cpp. */
public final class Detectors {
    private Detectors() {}

    public static List<Detector> all() {
        return Collections.unmodifiableList(Arrays.<Detector>asList(
                new RootBeerCheck(),
                new BuildTagsCheck(),
                new EmulatorScorer(),
                new JavaDebuggerCheck(),
                new SignatureCheck(),
                new DebuggableCheck(),
                new NativeVsJavaCrossCheck(),
                new InstallerCheck(),
                new AdbDevOptionsCheck(),
                new DeviceLockCheck(),
                new VpnCheck()));
    }
}
