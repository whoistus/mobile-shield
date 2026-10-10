package io.mobileshield;

import com.google.crypto.tink.subtle.Base64;
import com.google.crypto.tink.subtle.Ed25519Sign;
import io.mobileshield.config.Bootstrap;
import io.mobileshield.config.CanonicalJson;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import org.json.JSONObject;

/** Shared builders for the config tests. */
final class TestSupport {
    static final String APP_ID = "io.mobileshield.example";
    static final long NOW = 1_800_000_000_000L;

    private TestSupport() {}

    static JSONObject config(long seq) throws Exception {
        return new JSONObject()
                .put("version", 1)
                .put("appId", APP_ID)
                .put("seq", seq)
                .put("policies", new JSONObject())
                .put("detectors", new JSONObject());
    }

    static Bootstrap bootstrap(String channel) {
        return new Bootstrap(channel, null, null, APP_ID);
    }

    static Bootstrap bootstrap(String channel, byte[] publicKey) {
        return new Bootstrap(channel, publicKey, null, APP_ID);
    }

    static Ed25519Sign.KeyPair newKeyPair() throws GeneralSecurityException {
        return Ed25519Sign.KeyPair.newKeyPair();
    }

    /** Signs every field except "signature" over its RFC 8785 canonical form, like the host backend does. */
    static JSONObject sign(JSONObject config, byte[] privateKey) throws Exception {
        JSONObject body = new JSONObject(config.toString());
        body.remove("signature");
        byte[] signature = new Ed25519Sign(privateKey).sign(CanonicalJson.of(body).getBytes(StandardCharsets.UTF_8));
        return new JSONObject(body.toString()).put("signature", Base64.encode(signature));
    }
}
