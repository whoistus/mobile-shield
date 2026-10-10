package io.mobileshield.config;

import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import java.util.Collections;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

/** Effective configuration after bootstrap + channel defaults + host config + floor. */
public final class AppliedConfig {
    public final String channel;
    public final Map<ThreatCategory, Action> policies;
    /** Detector ids switched off by the host (floor ids never appear here on prod). */
    public final Set<String> disabled;
    public final double blockThreshold;
    public final long monitoringIntervalMs;
    public final long killDelayMinMs;
    public final long killDelayMaxMs;
    public final List<String> installerAllowlist;
    public final long seq;
    /** Human-readable list of values the floor overrode; empty when nothing was clamped. */
    public final List<String> clamped;

    AppliedConfig(String channel, Map<ThreatCategory, Action> policies, Set<String> disabled,
                  double blockThreshold, long monitoringIntervalMs, long killDelayMinMs,
                  long killDelayMaxMs, List<String> installerAllowlist, long seq, List<String> clamped) {
        this.channel = channel;
        this.policies = Collections.unmodifiableMap(new EnumMap<>(policies));
        this.disabled = Collections.unmodifiableSet(new TreeSet<>(disabled));
        this.blockThreshold = blockThreshold;
        this.monitoringIntervalMs = monitoringIntervalMs;
        this.killDelayMinMs = killDelayMinMs;
        this.killDelayMaxMs = killDelayMaxMs;
        this.installerAllowlist = Collections.unmodifiableList(installerAllowlist);
        this.seq = seq;
        this.clamped = Collections.unmodifiableList(clamped);
    }

    public boolean isEnabled(String detectorId) {
        return !disabled.contains(detectorId);
    }

    public Action policy(ThreatCategory c) {
        Action a = policies.get(c);
        return a == null ? Action.REPORT : a;
    }

    public JSONObject toJson() {
        try {
            JSONObject p = new JSONObject();
            for (Map.Entry<ThreatCategory, Action> e : policies.entrySet()) p.put(e.getKey().name(), e.getValue().name());
            JSONObject o = new JSONObject();
            o.put("channel", channel);
            o.put("policies", p);
            o.put("disabled", new JSONArray(disabled));
            o.put("blockThreshold", blockThreshold);
            o.put("monitoringIntervalMs", monitoringIntervalMs);
            o.put("killDelayMsRange", new JSONArray().put(killDelayMinMs).put(killDelayMaxMs));
            o.put("installerAllowlist", new JSONArray(installerAllowlist));
            o.put("seq", seq);
            o.put("clamped", new JSONArray(clamped));
            return o;
        } catch (JSONException e) {
            throw new IllegalStateException(e);
        }
    }
}
