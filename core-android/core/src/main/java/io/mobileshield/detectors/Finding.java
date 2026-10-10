package io.mobileshield.detectors;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

/** Outcome of one detector run. Details never carry PII (counts and signal names only). */
public final class Finding {
    public static final Finding NONE = new Finding(0d, null);
    public static final Finding UNSUPPORTED = new Finding(-1d, null);

    public final double confidence;
    public final Map<String, String> details;

    private Finding(double confidence, Map<String, String> details) {
        this.confidence = confidence;
        this.details = details == null
                ? Collections.<String, String>emptyMap()
                : Collections.unmodifiableMap(new LinkedHashMap<>(details));
    }

    public static Finding hit(double confidence) {
        return confidence > 0 ? new Finding(Math.min(1d, confidence), null) : NONE;
    }

    public static Finding hit(double confidence, String key, String value) {
        if (confidence <= 0) return NONE;
        Map<String, String> d = new LinkedHashMap<>();
        d.put(key, value);
        return new Finding(Math.min(1d, confidence), d);
    }

    public boolean isHit() {
        return confidence > 0;
    }
}
