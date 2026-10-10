package io.mobileshield.detectors;

import android.os.Debug;
import io.mobileshield.model.ThreatCategory;

/** debugger.javaDebugger: a JDWP debugger is attached or the VM is waiting for one. */
public final class JavaDebuggerCheck implements Detector {
    @Override public String id() { return "debugger.javaDebugger"; }
    @Override public ThreatCategory category() { return ThreatCategory.DEBUGGER; }

    @Override public Finding run(DetectorEnv env) {
        try {
            return Finding.hit(Debug.isDebuggerConnected() || Debug.waitingForDebugger() ? 0.95 : 0);
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }
}
