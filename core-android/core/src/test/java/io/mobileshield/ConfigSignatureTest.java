package io.mobileshield;

import static io.mobileshield.TestSupport.NOW;
import static io.mobileshield.TestSupport.bootstrap;
import static io.mobileshield.TestSupport.config;
import static io.mobileshield.TestSupport.newKeyPair;
import static io.mobileshield.TestSupport.sign;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import com.google.crypto.tink.subtle.Ed25519Sign;
import io.mobileshield.MobileShieldException.ConfigReason;
import io.mobileshield.config.CanonicalJson;
import io.mobileshield.config.ConfigEngine;
import io.mobileshield.config.ConfigEngine.Result;
import io.mobileshield.config.ConfigEngine.Status;
import io.mobileshield.config.ConfigVerifier;
import org.json.JSONObject;
import org.junit.Test;

/** Ed25519 verification over RFC 8785 canonical JSON. */
public class ConfigSignatureTest {
    private static Result apply(byte[] publicKey, JSONObject cfg) {
        return ConfigEngine.apply(bootstrap("prod", publicKey), null, NOW, cfg);
    }

    @Test
    public void validSignatureIsAccepted() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        JSONObject signed = sign(config(3).put("blockThreshold", 0.8), kp.getPrivateKey());
        Result r = apply(kp.getPublicKey(), signed);
        assertEquals(Status.APPLIED, r.status);
        assertEquals(3, r.applied.seq);
        assertTrue(r.events.isEmpty());
    }

    @Test
    public void keyOrderOfTheSignedDocumentDoesNotMatter() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        JSONObject signed = sign(config(1), kp.getPrivateKey());
        JSONObject reordered = new JSONObject();
        String[] names = {"signature", "detectors", "seq", "policies", "appId", "version"};
        for (String n : names) reordered.put(n, signed.get(n));
        assertTrue(ConfigVerifier.verify(reordered, kp.getPublicKey()));
    }

    @Test
    public void tamperedBodyIsRejectedWithBadSignatureEvent() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        JSONObject signed = sign(config(1), kp.getPrivateKey());
        signed.put("policies", new JSONObject().put("ROOT", "REPORT"));
        Result r = apply(kp.getPublicKey(), signed);
        assertEquals(Status.REJECTED, r.status);
        assertEquals(ConfigReason.signature, r.reason);
        assertNull(r.applied);
        assertEquals(1, r.events.size());
        assertEquals(ConfigEngine.EVENT_BAD_SIGNATURE, r.events.get(0).detectorId);
        assertEquals(0.5, r.events.get(0).confidence, 0);
    }

    @Test
    public void missingOrEmptySignatureIsRejectedWhenAKeyIsPinned() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        assertEquals(ConfigReason.signature, apply(kp.getPublicKey(), config(1)).reason);
        assertEquals(ConfigReason.signature, apply(kp.getPublicKey(), config(1).put("signature", "")).reason);
    }

    @Test
    public void malformedSignatureIsRejectedNotThrown() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        for (String junk : new String[] {"%%%not-base64%%%", "AAAA", "ZGVhZGJlZWY="}) {
            Result r = apply(kp.getPublicKey(), config(1).put("signature", junk));
            assertEquals(junk, ConfigReason.signature, r.reason);
        }
    }

    @Test
    public void signatureFromAnotherKeyIsRejected() throws Exception {
        JSONObject signed = sign(config(1), newKeyPair().getPrivateKey());
        assertEquals(ConfigReason.signature, apply(newKeyPair().getPublicKey(), signed).reason);
    }

    @Test
    public void invalidPinnedKeyRejectsEverything() throws Exception {
        JSONObject signed = sign(config(1), newKeyPair().getPrivateKey());
        assertEquals(ConfigReason.signature, apply(new byte[0], signed).reason);
        assertEquals(ConfigReason.signature, apply(new byte[31], signed).reason);
    }

    @Test
    public void signatureIsCheckedBeforeSchema() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        Result r = apply(kp.getPublicKey(), config(1).put("version", 99));
        assertEquals(ConfigReason.signature, r.reason);
    }

    @Test
    public void validlySignedButWrongAppIdIsStillRejectedBySchema() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        JSONObject signed = sign(config(1).put("appId", "com.other"), kp.getPrivateKey());
        assertEquals(ConfigReason.schema, apply(kp.getPublicKey(), signed).reason);
    }

    @Test
    public void replayOfAnOlderSignedConfigIsRejected() throws Exception {
        Ed25519Sign.KeyPair kp = newKeyPair();
        JSONObject old = sign(config(2), kp.getPrivateKey());
        Result r = ConfigEngine.apply(bootstrap("prod", kp.getPublicKey()), 3L, NOW, old);
        assertEquals(ConfigReason.expired, r.reason);
    }

    @Test
    public void noPinnedKeyMeansSignatureIsNotRequired() throws Exception {
        assertEquals(Status.APPLIED, ConfigEngine.apply(bootstrap("dev"), null, NOW, config(1)).status);
    }

    @Test
    public void canonicalJsonSortsKeysAndDropsWhitespace() throws Exception {
        JSONObject o = new JSONObject("{\"b\":[true,null,\"x\"],\"a\":{\"z\":1,\"y\":2},\"\\u00e9\":0,\"B\":1}");
        assertEquals("{\"B\":1,\"a\":{\"y\":2,\"z\":1},\"b\":[true,null,\"x\"],\"\u00e9\":0}", CanonicalJson.of(o));
    }

    @Test
    public void canonicalJsonEscapesLikeRfc8785() {
        assertEquals("\"a\\\"b\\\\c\\n\\u0001\u007f\u00e9\"", CanonicalJson.of("a\"b\\c\n\u0001\u007f\u00e9"));
        assertEquals("\"\\b\\f\\r\\t\"", CanonicalJson.of("\b\f\r\t"));
    }

    @Test
    public void canonicalJsonNumbersFollowEcmaScript() {
        String[][] cases = {
            {"0", "0"}, {"-0.0", "0"}, {"1", "1"}, {"100", "100"}, {"0.7", "0.7"}, {"-4.5", "-4.5"},
            {"0.002", "0.002"}, {"1e21", "1e+21"}, {"1e-7", "1e-7"}, {"123456789012345680000", "123456789012345680000"},
        };
        for (String[] c : cases) assertEquals(c[0], c[1], CanonicalJson.of(Double.parseDouble(c[0])));
        assertEquals("9007199254740992", CanonicalJson.of(9007199254740992L));
    }

    @Test
    public void canonicalJsonNumbersMatchRfc8785AppendixB() {
        Object[][] cases = {
            {0x0000000000000001L, "5e-324"},
            {0x8000000000000001L, "-5e-324"},
            {0x7fefffffffffffffL, "1.7976931348623157e+308"},
            {0xffefffffffffffffL, "-1.7976931348623157e+308"},
            {0x4340000000000000L, "9007199254740992"},
            {0xc340000000000000L, "-9007199254740992"},
            {0x4430000000000000L, "295147905179352830000"},
            {0x44b52d02c7e14af5L, "9.999999999999997e+22"},
            {0x44b52d02c7e14af6L, "1e+23"},
            {0x44b52d02c7e14af7L, "1.0000000000000001e+23"},
            {0x444b1ae4d6e2ef4eL, "999999999999999700000"},
            {0x444b1ae4d6e2ef4fL, "999999999999999900000"},
            {0x444b1ae4d6e2ef50L, "1e+21"},
            {0x3eb0c6f7a0b5ed8cL, "9.999999999999997e-7"},
            {0x3eb0c6f7a0b5ed8dL, "0.000001"},
            {0x41b3de4355555553L, "333333333.3333332"},
        };
        for (Object[] c : cases) {
            double d = Double.longBitsToDouble((Long) c[0]);
            assertEquals(Long.toHexString((Long) c[0]), c[1], CanonicalJson.of(d));
        }
    }

    @Test
    public void canonicalJsonRejectsNonFiniteNumbers() {
        try {
            CanonicalJson.of(Double.NaN);
            fail("NaN must be rejected");
        } catch (IllegalArgumentException expected) {
            assertTrue(expected.getMessage().contains("non-finite"));
        }
        try {
            CanonicalJson.of(Double.NEGATIVE_INFINITY);
            fail("Infinity must be rejected");
        } catch (IllegalArgumentException expected) {
            assertFalse(expected.getMessage().isEmpty());
        }
    }
}
