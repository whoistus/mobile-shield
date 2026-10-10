package io.mobileshield;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import com.google.crypto.tink.subtle.Base64;
import io.mobileshield.config.AppliedConfig;
import io.mobileshield.config.Bootstrap;
import io.mobileshield.config.ConfigEngine;
import io.mobileshield.model.ThreatCategory;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.Test;

/** Runs every android/any vector of scripts/fixtures/config-vectors.json through ConfigEngine. */
public class ConfigVectorsTest {

    private static JSONObject fixture() throws Exception {
        byte[] raw = Files.readAllBytes(Paths.get("..", "..", "scripts", "fixtures", "config-vectors.json"));
        return new JSONObject(new String(raw, StandardCharsets.UTF_8));
    }

    @Test
    public void allSharedVectorsPass() throws Exception {
        JSONObject fx = fixture();
        byte[] key = Base64.decode(fx.getString("testPublicKeyEd25519"));
        String appId = fx.getString("appId");
        JSONArray vectors = fx.getJSONArray("vectors");
        int ran = 0;
        List<String> failures = new ArrayList<>();
        for (int i = 0; i < vectors.length(); i++) {
            JSONObject v = vectors.getJSONObject(i);
            String platform = v.getString("platform");
            if (!platform.equals("any") && !platform.equals("android")) continue;
            ran++;
            try {
                check(v, key, appId);
            } catch (AssertionError e) {
                failures.add(v.getString("name") + ": " + e.getMessage());
            }
        }
        assertTrue("no vectors ran", ran > 10);
        assertTrue(String.join("\n", failures), failures.isEmpty());
    }

    private static void check(JSONObject v, byte[] key, String appId) throws Exception {
        String channel = v.isNull("channel") ? null : v.getString("channel");
        boolean pub = v.getJSONObject("bootstrap").getBoolean("pubkey");
        Long lkg = v.isNull("lastKnownGoodSeq") ? null : v.getLong("lastKnownGoodSeq");
        Bootstrap b = new Bootstrap(channel, pub ? key : null, null, appId);

        ConfigEngine.Result r = ConfigEngine.apply(b, lkg, v.getLong("now"), v.getJSONObject("config"));
        JSONObject exp = v.getJSONObject("expect");

        assertEquals("status", exp.getString("result").toUpperCase(), r.status.name());
        if (exp.has("reason")) {
            assertNotNull("reason", r.reason);
            assertEquals("reason", exp.getString("reason"), r.reason.name());
        } else {
            assertNull("reason", r.reason);
        }
        if (exp.has("policies")) {
            AppliedConfig a = r.applied;
            assertNotNull("applied", a);
            JSONObject ep = exp.getJSONObject("policies");
            for (Iterator<String> it = ep.keys(); it.hasNext(); ) {
                String c = it.next();
                assertEquals("policy " + c, ep.getString(c), a.policy(ThreatCategory.parse(c)).name());
            }
        }
        if (exp.has("disabled")) {
            List<String> want = new ArrayList<>();
            JSONArray d = exp.getJSONArray("disabled");
            for (int i = 0; i < d.length(); i++) want.add(d.getString(i));
            Collections.sort(want);
            assertEquals("disabled", want, new ArrayList<>(r.applied.disabled));
        }
        JSONArray ev = exp.getJSONArray("events");
        assertEquals("event count", ev.length(), r.events.size());
        for (int i = 0; i < ev.length(); i++) {
            JSONObject e = ev.getJSONObject(i);
            ConfigEngine.PolicyEvent got = r.events.get(i);
            assertEquals("event category", e.getString("category"), got.category.name());
            assertEquals("event detectorId", e.getString("detectorId"), got.detectorId);
            assertEquals("event confidence", e.getDouble("confidence"), got.confidence, 1e-9);
        }
    }
}
