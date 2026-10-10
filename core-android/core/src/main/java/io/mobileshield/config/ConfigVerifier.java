package io.mobileshield.config;

import com.google.crypto.tink.subtle.Base64;
import com.google.crypto.tink.subtle.Ed25519Verify;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import org.json.JSONObject;

/** Verifies the Ed25519 signature over the canonical JSON of every field except "signature". */
public final class ConfigVerifier {
    private ConfigVerifier() {}

    public static boolean verify(JSONObject config, byte[] publicKey) {
        if (publicKey == null || publicKey.length != 32) return false;
        String sigB64 = config.optString("signature", null);
        if (sigB64 == null || sigB64.isEmpty()) return false;
        try {
            byte[] sig = Base64.decode(sigB64);
            if (sig == null) return false;
            JSONObject body = new JSONObject(config.toString());
            body.remove("signature");
            byte[] message = CanonicalJson.of(body).getBytes(StandardCharsets.UTF_8);
            new Ed25519Verify(publicKey).verify(sig, message);
            return true;
        } catch (GeneralSecurityException | IllegalArgumentException | org.json.JSONException e) {
            return false;
        }
    }
}
