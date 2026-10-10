package io.mobileshield.detectors;

import android.os.Build;
import io.mobileshield.model.ThreatCategory;

/** root.buildTags: test-keys is common on community ROMs, so it carries weight 0.2. */
public final class BuildTagsCheck implements Detector {
    @Override public String id() { return "root.buildTags"; }
    @Override public ThreatCategory category() { return ThreatCategory.ROOT; }

    @Override public Finding run(DetectorEnv env) {
        return Finding.hit(Build.TAGS != null && Build.TAGS.contains("test-keys") ? 0.2 : 0);
    }
}
