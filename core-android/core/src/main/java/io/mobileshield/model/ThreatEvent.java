package io.mobileshield.model;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import org.json.JSONException;
import org.json.JSONObject;

/** Immutable threat event delivered to the host. Details never carry PII. */
public final class ThreatEvent {
    public final ThreatCategory category;
    public final Severity severity;
    public final double confidence;
    public final String detectorId;
    public final Action action;
    public final long timestamp;
    public final String platform = "android";
    public final Map<String, String> details;

    public ThreatEvent(ThreatCategory category, double confidence, String detectorId,
                       Action action, long timestamp, Map<String, String> details) {
        this.category = category;
        this.severity = category.severity;
        this.confidence = Math.max(0d, Math.min(1d, confidence));
        this.detectorId = detectorId;
        this.action = action;
        this.timestamp = timestamp;
        this.details = details == null
                ? Collections.<String, String>emptyMap()
                : Collections.unmodifiableMap(new LinkedHashMap<>(details));
    }

    public JSONObject toJson() {
        try {
            JSONObject o = new JSONObject();
            o.put("category", category.name());
            o.put("severity", severity.name());
            o.put("confidence", confidence);
            o.put("detectorId", detectorId);
            o.put("action", action.name());
            o.put("timestamp", timestamp);
            o.put("platform", platform);
            if (!details.isEmpty()) o.put("details", new JSONObject(details));
            return o;
        } catch (JSONException e) {
            throw new IllegalStateException(e);
        }
    }

    @Override
    public String toString() {
        return toJson().toString();
    }
}
