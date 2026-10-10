package io.mobileshield.detectors;

import io.mobileshield.model.ThreatCategory;

/** A Java-side detector. Reports evidence only; the native policy decides the action. */
public interface Detector {
    String id();

    ThreatCategory category();

    /** Must not throw; a detector that cannot run returns {@link Finding#UNSUPPORTED}. */
    Finding run(DetectorEnv env);
}
