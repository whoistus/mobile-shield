package io.mobileshield.detectors;

import android.content.pm.ApplicationInfo;
import io.mobileshield.model.ThreatCategory;

/** tampering.debuggable: FLAG_DEBUGGABLE set on the running app. */
public final class DebuggableCheck implements Detector {
    @Override public String id() { return "tampering.debuggable"; }
    @Override public ThreatCategory category() { return ThreatCategory.TAMPERING; }

    @Override public Finding run(DetectorEnv env) {
        try {
            return Finding.hit((env.context.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0 ? 0.8 : 0);
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }
}
