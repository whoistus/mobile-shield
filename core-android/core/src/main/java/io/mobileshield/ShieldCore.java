package io.mobileshield;

import io.mobileshield.config.AppliedConfig;
import io.mobileshield.config.Bootstrap;
import io.mobileshield.config.ConfigEngine;
import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import io.mobileshield.model.ThreatEvent;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import org.json.JSONObject;

/**
 * Config state machine and check cycles, free of Android so it runs on the JVM.
 *
 * <p>One lock covers "collect findings with config N and decide them with policy N" and "commit
 * config N+1 (+ native policy + persistence)", so a finding is never decided under a different
 * config than the one that produced it. Listeners run after the lock is released: a listener may
 * call {@link #update} and its sequence is never rolled back by the outer call.
 */
final class ShieldCore {
    interface Platform {
        void push(AppliedConfig config);
        Long lastKnownSeq();
        void save(JSONObject raw, long seq);
        Action decide(ThreatCategory category, String detectorId, double confidence);
        List<CheckRunner.Hit> collect(AppliedConfig config);
    }

    private final Object lock = new Object();
    private final Bootstrap bootstrap;
    private final Platform platform;
    private final EventHub hub;
    private volatile AppliedConfig config;

    ShieldCore(Bootstrap bootstrap, Platform platform, EventHub hub) {
        this.hub = hub;
        this.bootstrap = bootstrap;
        this.platform = platform;
        this.config = ConfigEngine.defaults(bootstrap);
        platform.push(config);
    }

    AppliedConfig config() { return config; }

    AppliedConfig update(JSONObject runtime, boolean reportClamp) throws MobileShieldException {
        List<ThreatEvent> events = new ArrayList<>();
        MobileShieldException failure = null;
        AppliedConfig current;
        synchronized (lock) {
            ConfigEngine.Result result = ConfigEngine.apply(bootstrap, platform.lastKnownSeq(), System.currentTimeMillis(), runtime);
            if (result.applied != null) {
                config = result.applied;
                platform.push(config);
                platform.save(runtime, config.seq);
            }
            for (ConfigEngine.PolicyEvent e : result.events) events.add(event(e.category, e.detectorId, e.confidence, null));
            boolean rejected = result.status == ConfigEngine.Status.REJECTED
                    || (result.status == ConfigEngine.Status.CLAMPED && reportClamp);
            if (rejected) {
                failure = new MobileShieldException(MobileShieldException.Reason.ConfigRejected, result.reason, result.message);
            }
            current = config;
        }
        hub.publish(events);
        if (failure != null) throw failure;
        return current;
    }

    List<ThreatEvent> runChecks() {
        List<ThreatEvent> events = new ArrayList<>();
        synchronized (lock) {
            for (CheckRunner.Hit hit : platform.collect(config)) {
                events.add(event(hit.category, hit.detectorId, hit.confidence, hit.details));
            }
        }
        hub.publish(events);
        return events;
    }

    void emitOne(ThreatCategory category, String detectorId, double confidence) {
        ThreatEvent event;
        synchronized (lock) {
            if (!config.isEnabled(detectorId)) return;
            event = event(category, detectorId, confidence, null);
        }
        hub.publish(Collections.singletonList(event));
    }

    private ThreatEvent event(ThreatCategory category, String id, double confidence, Map<String, String> details) {
        Action action = platform.decide(category, id, confidence);
        return new ThreatEvent(category, confidence, id, action, System.currentTimeMillis(), details);
    }
}
