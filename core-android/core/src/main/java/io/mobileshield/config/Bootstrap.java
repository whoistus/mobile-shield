package io.mobileshield.config;

import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import com.google.crypto.tink.subtle.Base64;

/**
 * Immutable bootstrap values read natively from the host's signed manifest, never from JS/Dart.
 * Missing channel fails closed to prod.
 */
public final class Bootstrap {
    public static final String META_CHANNEL = "io.mobileshield.CHANNEL";
    public static final String META_CONFIG_PUBKEY = "io.mobileshield.CONFIG_PUBKEY";
    public static final String META_SIGNING_SHA256 = "io.mobileshield.SIGNING_SHA256";

    public final String channel;
    /** Raw 32-byte Ed25519 public key, or null when the host ships none. */
    public final byte[] configPublicKey;
    /** Expected signing certificate SHA-256 pin(s): lowercase hex, comma separated, or null. */
    public final String signingSha256;
    public final String appId;

    public Bootstrap(String channel, byte[] configPublicKey, String signingSha256, String appId) {
        this.channel = Defaults.channel(channel);
        this.configPublicKey = configPublicKey;
        this.signingSha256 = normaliseHex(signingSha256);
        this.appId = appId;
    }

    public boolean isProd() {
        return Defaults.CHANNEL_PROD.equals(channel);
    }

    public static Bootstrap fromManifest(Context context) {
        Bundle meta = null;
        try {
            ApplicationInfo ai = context.getPackageManager()
                    .getApplicationInfo(context.getPackageName(), PackageManager.GET_META_DATA);
            meta = ai.metaData;
        } catch (PackageManager.NameNotFoundException ignored) {
            // Own package always exists; fall through with no metadata (prod, no key).
        }
        String channel = meta == null ? null : meta.getString(META_CHANNEL);
        String key = meta == null ? null : meta.getString(META_CONFIG_PUBKEY);
        String sha = meta == null ? null : meta.getString(META_SIGNING_SHA256);
        return new Bootstrap(channel, decodeKey(key), sha, context.getPackageName());
    }

    /** Decodes a base64 raw Ed25519 key; anything malformed is treated as absent-but-required. */
    static byte[] decodeKey(String b64) {
        if (b64 == null || b64.trim().isEmpty()) return null;
        try {
            byte[] k = Base64.decode(b64.trim());
            return k != null && k.length == 32 ? k : new byte[0];
        } catch (IllegalArgumentException e) {
            return new byte[0];
        }
    }

    /** Lowercase hex without separators; several pins may be comma separated (key rotation). */
    static String normaliseHex(String hex) {
        if (hex == null) return null;
        StringBuilder out = new StringBuilder();
        for (String pin : hex.split(",")) {
            String h = pin.replace(":", "").trim().toLowerCase(java.util.Locale.ROOT);
            if (h.isEmpty()) continue;
            if (out.length() > 0) out.append(',');
            out.append(h);
        }
        return out.length() == 0 ? null : out.toString();
    }
}
