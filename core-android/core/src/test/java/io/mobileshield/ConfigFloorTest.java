package io.mobileshield;

import static io.mobileshield.TestSupport.NOW;
import static io.mobileshield.TestSupport.bootstrap;
import static io.mobileshield.TestSupport.config;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;

import io.mobileshield.MobileShieldException.ConfigReason;
import io.mobileshield.config.ConfigEngine;
import io.mobileshield.config.ConfigEngine.Result;
import io.mobileshield.config.ConfigEngine.Status;
import io.mobileshield.config.Defaults;
import io.mobileshield.model.Action;
import io.mobileshield.model.ThreatCategory;
import org.json.JSONObject;
import org.junit.Test;

/** Prod floor: identity checks cannot be disabled and TAMPERING cannot drop below WARN. */
public class ConfigFloorTest {
    private static Result apply(String channel, JSONObject cfg) {
        return ConfigEngine.apply(bootstrap(channel), null, NOW, cfg);
    }

    private static void assertSingleFloorEvent(Result r) {
        assertEquals(1, r.events.size());
        assertEquals(ConfigEngine.EVENT_FLOOR, r.events.get(0).detectorId);
        assertEquals(ThreatCategory.TAMPERING, r.events.get(0).category);
        assertEquals(0.5, r.events.get(0).confidence, 0);
        assertTrue("floor event must stay below the block threshold", r.events.get(0).confidence < Defaults.BLOCK_THRESHOLD);
    }

    @Test
    public void signatureCheckCannotBeDisabledOnProd() throws Exception {
        Result r = apply("prod", config(1).put("detectors", new JSONObject().put("tampering.signature", false)));
        assertEquals(Status.CLAMPED, r.status);
        assertEquals(ConfigReason.floor, r.reason);
        assertTrue(r.applied.isEnabled("tampering.signature"));
        assertTrue(r.applied.clamped.contains("detectors.tampering.signature"));
        assertSingleFloorEvent(r);
    }

    @Test
    public void nativeVsJavaCannotBeDisabledOnProd() throws Exception {
        Result r = apply("prod", config(1).put("detectors", new JSONObject().put("tampering.nativeVsJava", false)));
        assertEquals(Status.CLAMPED, r.status);
        assertTrue(r.applied.isEnabled("tampering.nativeVsJava"));
    }

    @Test
    public void tamperingPolicyBelowWarnIsRaisedOnProd() throws Exception {
        Result r = apply("prod", config(1).put("policies", new JSONObject().put("TAMPERING", "REPORT")));
        assertEquals(Status.CLAMPED, r.status);
        assertEquals(Action.WARN, r.applied.policy(ThreatCategory.TAMPERING));
        assertTrue(r.applied.clamped.contains("policies.TAMPERING"));
    }

    @Test
    public void tighteningTamperingIsNotClamped() throws Exception {
        for (String action : new String[] {"WARN", "BLOCK", "KILL"}) {
            Result r = apply("prod", config(1).put("policies", new JSONObject().put("TAMPERING", action)));
            assertEquals(action, Status.APPLIED, r.status);
            assertEquals(action, r.applied.policy(ThreatCategory.TAMPERING).name());
            assertTrue(r.events.isEmpty());
        }
    }

    @Test
    public void severalViolationsRaiseOneFloorEvent() throws Exception {
        JSONObject cfg = config(1)
                .put("policies", new JSONObject().put("TAMPERING", "REPORT"))
                .put("detectors", new JSONObject().put("tampering.signature", false).put("tampering.nativeVsJava", false));
        Result r = apply("prod", cfg);
        assertEquals(3, r.applied.clamped.size());
        assertSingleFloorEvent(r);
    }

    @Test
    public void otherDetectorsAndCategoriesStayConfigurableOnProd() throws Exception {
        JSONObject cfg = config(1)
                .put("policies", new JSONObject().put("ROOT", "REPORT").put("EMULATOR", "REPORT"))
                .put("detectors", new JSONObject().put("tampering.debuggable", false).put("hooking.prologue", false));
        Result r = apply("prod", cfg);
        assertEquals(Status.APPLIED, r.status);
        assertFalse(r.applied.isEnabled("tampering.debuggable"));
        assertEquals(Action.REPORT, r.applied.policy(ThreatCategory.ROOT));
    }

    @Test
    public void floorDoesNotApplyOutsideProd() throws Exception {
        JSONObject cfg = config(1)
                .put("policies", new JSONObject().put("TAMPERING", "REPORT"))
                .put("detectors", new JSONObject().put("tampering.signature", false));
        for (String channel : new String[] {"dev", "test"}) {
            Result r = apply(channel, cfg);
            assertEquals(channel, Status.APPLIED, r.status);
            assertEquals(Action.REPORT, r.applied.policy(ThreatCategory.TAMPERING));
            assertFalse(r.applied.isEnabled("tampering.signature"));
            assertTrue(r.events.isEmpty());
        }
    }

    @Test
    public void missingChannelGetsTheProdFloor() throws Exception {
        Result r = apply(null, config(1).put("detectors", new JSONObject().put("tampering.signature", false)));
        assertEquals(Status.CLAMPED, r.status);
    }

    @Test
    public void clampedConfigIsStillAppliedWithFlooredValues() throws Exception {
        Result r = apply("prod", config(9).put("policies", new JSONObject().put("TAMPERING", "REPORT").put("VPN_PROXY", "WARN")));
        assertNotNull(r.applied);
        assertEquals(9, r.applied.seq);
        assertEquals(Action.WARN, r.applied.policy(ThreatCategory.VPN_PROXY));
    }

    @Test
    public void experimentalIdsMayAlwaysBeDisabled() throws Exception {
        JSONObject flags = new JSONObject();
        for (String id : Defaults.EXPERIMENTAL_IDS) flags.put(id, false);
        Result r = apply("prod", config(1).put("detectors", flags));
        assertEquals(Status.APPLIED, r.status);
        assertEquals(Defaults.EXPERIMENTAL_IDS.size(), r.applied.disabled.size());
    }
}
