package io.mobileshield;

import android.content.Context;
import io.mobileshield.config.AppliedConfig;
import io.mobileshield.config.Bootstrap;
import io.mobileshield.detectors.Detector;
import io.mobileshield.detectors.DetectorEnv;
import io.mobileshield.detectors.Detectors;
import io.mobileshield.detectors.Finding;
import io.mobileshield.internal.NativeBridge;
import io.mobileshield.model.ThreatCategory;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/** Runs the native and Java detectors once and returns raw hits; the policy decides actions later. */
final class CheckRunner {
    static final class Hit {
        final ThreatCategory category;
        final String detectorId;
        final double confidence;
        final Map<String, String> details;

        Hit(ThreatCategory category, String detectorId, double confidence, Map<String, String> details) {
            this.category = category;
            this.detectorId = detectorId;
            this.confidence = confidence;
            this.details = details;
        }
    }

    private final List<Detector> javaDetectors = Detectors.all();

    List<Hit> run(Context context, Bootstrap bootstrap, AppliedConfig config) {
        List<Hit> hits = new ArrayList<>();
        NativeBridge.Entry[] catalog = NativeBridge.catalog();
        float[] results = NativeBridge.runChecks(config.disabled.toArray(new String[0]));
        if (results != null && results.length == catalog.length) {
            for (int i = 0; i < catalog.length; i++) {
                if (results[i] > 0f) {
                    hits.add(new Hit(catalog[i].category, catalog[i].id, results[i], Collections.<String, String>emptyMap()));
                }
            }
        }
        DetectorEnv env = new DetectorEnv(context, bootstrap, config);
        for (Detector detector : javaDetectors) {
            if (!config.isEnabled(detector.id())) continue;
            Finding finding = runSafely(detector, env);
            if (finding.isHit()) hits.add(new Hit(detector.category(), detector.id(), finding.confidence, finding.details));
        }
        return hits;
    }

    private static Finding runSafely(Detector detector, DetectorEnv env) {
        try {
            return detector.run(env);
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }
}
