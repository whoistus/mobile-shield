package io.mobileshield;

import static io.mobileshield.TestSupport.NOW;
import static io.mobileshield.TestSupport.bootstrap;
import static io.mobileshield.TestSupport.config;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import io.mobileshield.MobileShieldException.ConfigReason;
import io.mobileshield.config.AppliedConfig;
import io.mobileshield.config.ConfigEngine;
import io.mobileshield.config.ConfigEngine.Result;
import io.mobileshield.config.ConfigEngine.Status;
import io.mobileshield.config.Defaults;
import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import java.util.Arrays;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;

/** Merge of host config over channel defaults, schema validation and freshness rules. */
public class ConfigMergeTest {
    private static Result apply(String channel, JSONObject cfg) {
        return ConfigEngine.apply(bootstrap(channel), null, NOW, cfg);
    }

    private static void assertRejected(JSONObject cfg, ConfigReason reason) {
        Result r = apply("dev", cfg);
        assertEquals(Status.REJECTED, r.status);
        assertEquals(reason, r.reason);
        assertNull(r.applied);
    }

    @Test
    public void emptyConfigYieldsChannelDefaults() throws Exception {
        Result r = apply("prod", config(1));
        assertEquals(Status.APPLIED, r.status);
        assertEquals(Defaults.policies("prod"), r.applied.policies);
        assertTrue(r.applied.disabled.isEmpty());
        assertEquals(Defaults.BLOCK_THRESHOLD, r.applied.blockThreshold, 0);
        assertEquals(Defaults.MONITORING_INTERVAL_MS, r.applied.monitoringIntervalMs);
        assertEquals(Defaults.INSTALLER_ALLOWLIST, r.applied.installerAllowlist);
    }

    @Test
    public void hostPoliciesOverrideDefaultsPerCategory() throws Exception {
        JSONObject cfg = config(1).put("policies", new JSONObject().put("VPN_PROXY", "WARN").put("DEBUGGER", "BLOCK"));
        AppliedConfig a = apply("prod", cfg).applied;
        assertEquals(Action.WARN, a.policy(ThreatCategory.VPN_PROXY));
        assertEquals(Action.BLOCK, a.policy(ThreatCategory.DEBUGGER));
        assertEquals(Action.BLOCK, a.policy(ThreatCategory.ROOT));
    }

    @Test
    public void killIsAcceptedOnlyWhenTheHostAsksForIt() throws Exception {
        AppliedConfig a = apply("prod", config(1).put("policies", new JSONObject().put("HOOKING", "KILL"))).applied;
        assertEquals(Action.KILL, a.policy(ThreatCategory.HOOKING));
    }

    @Test
    public void detectorFlagsDisableOnlyWhenFalse() throws Exception {
        JSONObject flags = new JSONObject().put("network.vpn", false).put("devoptions.adb", true);
        AppliedConfig a = apply("dev", config(1).put("detectors", flags)).applied;
        assertFalse(a.isEnabled("network.vpn"));
        assertTrue(a.isEnabled("devoptions.adb"));
        assertTrue(a.isEnabled("root.suPaths"));
    }

    @Test
    public void tunablesAreMerged() throws Exception {
        JSONObject cfg = config(7)
                .put("blockThreshold", 0.85)
                .put("monitoringIntervalMs", 2500)
                .put("killDelayMsRange", new JSONArray(Arrays.asList(100, 200)))
                .put("installerAllowlist", new JSONArray(Arrays.asList("com.corp.mdm")));
        AppliedConfig a = apply("dev", cfg).applied;
        assertEquals(0.85, a.blockThreshold, 0);
        assertEquals(2500, a.monitoringIntervalMs);
        assertEquals(100, a.killDelayMinMs);
        assertEquals(200, a.killDelayMaxMs);
        assertEquals(Arrays.asList("com.corp.mdm"), a.installerAllowlist);
        assertEquals(7, a.seq);
    }

    @Test
    public void thresholdBoundariesAreInclusive() throws Exception {
        assertEquals(Status.APPLIED, apply("dev", config(1).put("blockThreshold", 0)).status);
        assertEquals(Status.APPLIED, apply("dev", config(1).put("blockThreshold", 1)).status);
        assertRejected(config(1).put("blockThreshold", -0.01), ConfigReason.schema);
        assertRejected(config(1).put("blockThreshold", 1.01), ConfigReason.schema);
    }

    @Test
    public void schemaViolationsAreRejected() throws Exception {
        assertRejected(config(1).put("version", 2), ConfigReason.schema);
        assertRejected(config(1).put("appId", "com.other.app"), ConfigReason.schema);
        assertRejected(config(1).put("policies", new JSONObject().put("NOPE", "WARN")), ConfigReason.schema);
        assertRejected(config(1).put("policies", new JSONObject().put("ROOT", "EXPLODE")), ConfigReason.schema);
        assertRejected(config(1).put("detectors", new JSONObject().put("network.vpn", "no")), ConfigReason.schema);
        assertRejected(config(1).put("monitoringIntervalMs", 999), ConfigReason.schema);
        assertRejected(config(1).put("killDelayMsRange", new JSONArray(Arrays.asList(5, 1))), ConfigReason.schema);
        assertRejected(config(1).put("killDelayMsRange", new JSONArray(Arrays.asList(5))), ConfigReason.schema);
        assertRejected(config(1).put("installerAllowlist", new JSONArray(Arrays.asList(""))), ConfigReason.schema);
        assertRejected(config(1).put("expiresAt", "soon"), ConfigReason.schema);
        JSONObject noSeq = config(1);
        noSeq.remove("seq");
        assertRejected(noSeq, ConfigReason.schema);
    }

    @Test
    public void nullConfigIsRejected() {
        Result r = ConfigEngine.apply(bootstrap("dev"), null, NOW, null);
        assertEquals(Status.REJECTED, r.status);
        assertEquals(ConfigReason.schema, r.reason);
    }

    @Test
    public void olderSeqThanLastKnownGoodIsRejectedAsExpired() throws Exception {
        Result stale = ConfigEngine.apply(bootstrap("dev"), 5L, NOW, config(4));
        assertEquals(Status.REJECTED, stale.status);
        assertEquals(ConfigReason.expired, stale.reason);
        assertEquals(Status.APPLIED, ConfigEngine.apply(bootstrap("dev"), 5L, NOW, config(5)).status);
        assertEquals(Status.APPLIED, ConfigEngine.apply(bootstrap("dev"), 5L, NOW, config(6)).status);
    }

    @Test
    public void expiredConfigIsRejectedAndFutureOneAccepted() throws Exception {
        Result expired = apply("dev", config(1).put("expiresAt", NOW));
        assertEquals(ConfigReason.expired, expired.reason);
        assertEquals(Status.APPLIED, apply("dev", config(1).put("expiresAt", NOW + 1)).status);
    }

    @Test
    public void defaultsHelperMatchesChannelTable() {
        AppliedConfig a = ConfigEngine.defaults(bootstrap(null));
        assertEquals("prod", a.channel);
        assertEquals(Defaults.policies("prod"), a.policies);
        assertEquals(0, a.seq);
        assertNotNull(a.toJson().optJSONObject("policies"));
        assertTrue(a.clamped.isEmpty());
    }
}
