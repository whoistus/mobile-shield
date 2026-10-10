package io.mobileshield.config;

import io.mobileshield.MobileShieldException.ConfigReason;
import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import java.util.ArrayList;
import java.util.Collections;
import java.util.EnumMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.json.JSONObject;

/**
 * Pure config pipeline: signature → schema → freshness → merge → floor.
 * No Android or native dependencies, so every shared vector runs on the JVM.
 */
public final class ConfigEngine {
    private ConfigEngine() {}

    public enum Status { APPLIED, CLAMPED, REJECTED }

    /** Policy-generated event; the action is decided later by the native policy. */
    public static final class PolicyEvent {
        public final ThreatCategory category;
        public final String detectorId;
        public final double confidence;

        PolicyEvent(ThreatCategory category, String detectorId, double confidence) {
            this.category = category;
            this.detectorId = detectorId;
            this.confidence = confidence;
        }
    }

    public static final class Result {
        public final Status status;
        public final ConfigReason reason;
        public final AppliedConfig applied;
        public final List<PolicyEvent> events;
        public final String message;

        Result(Status status, ConfigReason reason, AppliedConfig applied, List<PolicyEvent> events, String message) {
            this.status = status;
            this.reason = reason;
            this.applied = applied;
            this.events = Collections.unmodifiableList(events);
            this.message = message;
        }
    }

    public static final String EVENT_FLOOR = "policy.floor";
    public static final String EVENT_BAD_SIGNATURE = "policy.badSignature";
    static final double POLICY_EVENT_CONFIDENCE = 0.5;

    /**
     * @param bootstrap     immutable bootstrap values
     * @param lastKnownSeq  seq of the persisted last-known-good config, or null
     * @param nowMs         current wall clock (epoch ms)
     * @param config        runtime config from the host
     */
    public static Result apply(Bootstrap bootstrap, Long lastKnownSeq, long nowMs, JSONObject config) {
        List<PolicyEvent> events = new ArrayList<>();
        if (config == null) return reject(ConfigReason.schema, "config is null", events);

        if (bootstrap.configPublicKey != null && !ConfigVerifier.verify(config, bootstrap.configPublicKey)) {
            events.add(new PolicyEvent(ThreatCategory.TAMPERING, EVENT_BAD_SIGNATURE, POLICY_EVENT_CONFIDENCE));
            return reject(ConfigReason.signature, "signature missing or invalid", events);
        }

        RuntimeConfig rc;
        try {
            rc = RuntimeConfig.parse(config, bootstrap.appId);
        } catch (RuntimeConfig.SchemaException e) {
            return reject(ConfigReason.schema, e.getMessage(), events);
        }

        if (lastKnownSeq != null && rc.seq < lastKnownSeq) {
            return reject(ConfigReason.expired, "seq older than last-known-good", events);
        }
        if (rc.expiresAt != null && rc.expiresAt <= nowMs) return reject(ConfigReason.expired, "config expired", events);

        Map<ThreatCategory, Action> policies = Defaults.policies(bootstrap.channel);
        policies.putAll(rc.policies);
        Set<String> disabled = new HashSet<>(rc.disabled);

        List<String> clamped = new ArrayList<>();
        if (bootstrap.isProd()) {
            for (String id : Defaults.FLOOR_IDS) {
                if (disabled.remove(id)) clamped.add("detectors." + id);
            }
            if (policies.get(ThreatCategory.TAMPERING).ordinal() < Defaults.FLOOR_MIN_TAMPERING.ordinal()) {
                policies.put(ThreatCategory.TAMPERING, Defaults.FLOOR_MIN_TAMPERING);
                clamped.add("policies.TAMPERING");
            }
        }

        AppliedConfig applied = new AppliedConfig(bootstrap.channel, new EnumMap<>(policies), disabled,
                rc.blockThreshold, rc.monitoringIntervalMs, rc.killDelayMinMs, rc.killDelayMaxMs,
                rc.installerAllowlist, rc.seq, clamped);
        if (!clamped.isEmpty()) {
            events.add(new PolicyEvent(ThreatCategory.TAMPERING, EVENT_FLOOR, POLICY_EVENT_CONFIDENCE));
            return new Result(Status.CLAMPED, ConfigReason.floor, applied, events, "clamped: " + clamped);
        }
        return new Result(Status.APPLIED, null, applied, events, "applied");
    }

    /** Config used before any host config arrives: channel defaults, nothing disabled. */
    public static AppliedConfig defaults(Bootstrap bootstrap) {
        return new AppliedConfig(bootstrap.channel, Defaults.policies(bootstrap.channel), new HashSet<String>(),
                Defaults.BLOCK_THRESHOLD, Defaults.MONITORING_INTERVAL_MS, Defaults.KILL_DELAY_MS_RANGE[0],
                Defaults.KILL_DELAY_MS_RANGE[1], new ArrayList<>(Defaults.INSTALLER_ALLOWLIST), 0,
                new ArrayList<String>());
    }

    private static Result reject(ConfigReason reason, String message, List<PolicyEvent> events) {
        return new Result(Status.REJECTED, reason, null, events, message);
    }
}
