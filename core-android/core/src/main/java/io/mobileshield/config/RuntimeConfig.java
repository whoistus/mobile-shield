package io.mobileshield.config;

import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.json.JSONArray;
import org.json.JSONObject;

/** Schema-validated host config, before it is merged over the channel defaults. Pure JVM. */
public final class RuntimeConfig {
    /** The input is not a valid RuntimeConfig; {@link #getMessage()} says which field. */
    public static final class SchemaException extends Exception {
        SchemaException(String message) {
            super(message);
        }
    }

    public final long seq;
    /** Epoch ms, or null when the config does not expire. */
    public final Long expiresAt;
    public final Map<ThreatCategory, Action> policies;
    /** Detector ids the host switched off (flag false). */
    public final Set<String> disabled;
    public final double blockThreshold;
    public final long monitoringIntervalMs;
    public final long killDelayMinMs;
    public final long killDelayMaxMs;
    public final List<String> installerAllowlist;

    private RuntimeConfig(long seq, Long expiresAt, Map<ThreatCategory, Action> policies, Set<String> disabled,
                          double blockThreshold, long monitoringIntervalMs, long killDelayMinMs,
                          long killDelayMaxMs, List<String> installerAllowlist) {
        this.seq = seq;
        this.expiresAt = expiresAt;
        this.policies = Collections.unmodifiableMap(policies);
        this.disabled = Collections.unmodifiableSet(disabled);
        this.blockThreshold = blockThreshold;
        this.monitoringIntervalMs = monitoringIntervalMs;
        this.killDelayMinMs = killDelayMinMs;
        this.killDelayMaxMs = killDelayMaxMs;
        this.installerAllowlist = Collections.unmodifiableList(installerAllowlist);
    }

    /** Validates every field with exact JSON types, like iOS ConfigEngine; absent optionals take the defaults. */
    public static RuntimeConfig parse(JSONObject config, String expectedAppId) throws SchemaException {
        Long version = integral(config.opt("version"));
        if (version == null || version != 1) throw new SchemaException("version must be 1");
        if (!expectedAppId.equals(config.opt("appId"))) {
            throw new SchemaException("appId does not match the package name");
        }
        Long seq = integral(config.opt("seq"));
        if (seq == null) throw new SchemaException("seq is required");

        Map<ThreatCategory, Action> policies = new EnumMap<>(ThreatCategory.class);
        if (config.has("policies")) {
            if (!(config.opt("policies") instanceof JSONObject)) throw new SchemaException("policies must be an object");
            JSONObject p = (JSONObject) config.opt("policies");
            for (Iterator<String> it = p.keys(); it.hasNext(); ) {
                String key = it.next();
                Object value = p.opt(key);
                ThreatCategory c = ThreatCategory.parse(key);
                Action a = value instanceof String ? Action.parse((String) value) : null;
                if (c == null || a == null) throw new SchemaException("bad policy " + key);
                policies.put(c, a);
            }
        }

        Set<String> disabled = new HashSet<>();
        if (config.has("detectors")) {
            if (!(config.opt("detectors") instanceof JSONObject)) throw new SchemaException("detectors must be an object");
            JSONObject d = (JSONObject) config.opt("detectors");
            for (Iterator<String> it = d.keys(); it.hasNext(); ) {
                String id = it.next();
                Object v = d.opt(id);
                if (!(v instanceof Boolean)) throw new SchemaException("detector flag must be boolean: " + id);
                if (!((Boolean) v)) disabled.add(id);
            }
        }

        double threshold = Defaults.BLOCK_THRESHOLD;
        if (config.has("blockThreshold")) {
            Double t = number(config.opt("blockThreshold"));
            if (t == null || t < 0 || t > 1) throw new SchemaException("blockThreshold must be within 0..1");
            threshold = t;
        }
        long interval = Defaults.MONITORING_INTERVAL_MS;
        if (config.has("monitoringIntervalMs")) {
            Long v = integral(config.opt("monitoringIntervalMs"));
            if (v == null || v < Defaults.MONITORING_INTERVAL_MIN_MS) {
                throw new SchemaException("monitoringIntervalMs below minimum");
            }
            interval = v;
        }

        long killMin = Defaults.KILL_DELAY_MS_RANGE[0];
        long killMax = Defaults.KILL_DELAY_MS_RANGE[1];
        if (config.has("killDelayMsRange")) {
            Object raw = config.opt("killDelayMsRange");
            Long low = null;
            Long high = null;
            if (raw instanceof JSONArray && ((JSONArray) raw).length() == 2) {
                low = integral(((JSONArray) raw).opt(0));
                high = integral(((JSONArray) raw).opt(1));
            }
            if (low == null || high == null || low < 0 || high < low) throw new SchemaException("bad killDelayMsRange");
            killMin = low;
            killMax = high;
        }

        List<String> allowlist = new ArrayList<>(Defaults.INSTALLER_ALLOWLIST);
        if (config.has("installerAllowlist")) {
            Object raw = config.opt("installerAllowlist");
            if (!(raw instanceof JSONArray)) throw new SchemaException("bad installerAllowlist");
            allowlist.clear();
            JSONArray al = (JSONArray) raw;
            for (int i = 0; i < al.length(); i++) {
                Object entry = al.opt(i);
                if (!(entry instanceof String) || ((String) entry).isEmpty()) throw new SchemaException("bad installerAllowlist");
                allowlist.add((String) entry);
            }
        }

        Long expiresAt = null;
        Object exp = config.opt("expiresAt");
        if (config.has("expiresAt") && exp != JSONObject.NULL) {
            expiresAt = integral(exp);
            if (expiresAt == null) throw new SchemaException("expiresAt must be epoch ms");
        }
        return new RuntimeConfig(seq, expiresAt, policies, disabled, threshold, interval, killMin, killMax, allowlist);
    }

    private static Double number(Object value) {
        if (!(value instanceof Number)) return null;
        double d = ((Number) value).doubleValue();
        return Double.isNaN(d) || Double.isInfinite(d) ? null : d;
    }

    /** Whole numbers only (5000.0 passes, 5000.5 and non-numbers do not). */
    private static Long integral(Object value) {
        if (value instanceof Long || value instanceof Integer || value instanceof Short || value instanceof Byte) {
            return ((Number) value).longValue();
        }
        Double d = number(value);
        if (d == null || d != Math.rint(d) || d < -9.223372036854775808E18 || d >= 9.223372036854775808E18) return null;
        return d.longValue();
    }
}
