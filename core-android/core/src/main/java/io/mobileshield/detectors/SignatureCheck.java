package io.mobileshield.detectors;

import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.os.Build;
import io.mobileshield.model.ThreatCategory;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.Locale;
import java.util.Set;

/** tampering.signature: signing certificates vs the SHA-256 pin(s) from the bootstrap manifest. */
public final class SignatureCheck implements Detector {
    static final double MISMATCH = 0.95;
    // Package manager failure is odd but not proof: stays below the default block threshold.
    static final double UNREADABLE = 0.6;

    @Override public String id() { return "tampering.signature"; }
    @Override public ThreatCategory category() { return ThreatCategory.TAMPERING; }

    /** Pins are lowercase hex digests, comma separated to allow key rotation. */
    public static boolean matches(Set<String> signerDigests, String pins) {
        if (pins == null || signerDigests.isEmpty()) return false;
        Set<String> allowed = new HashSet<>();
        for (String p : pins.split(",")) {
            String t = p.trim();
            if (!t.isEmpty()) allowed.add(t);
        }
        return allowed.containsAll(signerDigests);
    }

    public static String sha256Hex(byte[] cert) throws java.security.NoSuchAlgorithmException {
        StringBuilder hex = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(cert)) hex.append(String.format(Locale.ROOT, "%02x", b & 0xff));
        return hex.toString();
    }

    @Override public Finding run(DetectorEnv env) {
        String pins = env.bootstrap.signingSha256;
        if (pins == null) return Finding.UNSUPPORTED;
        try {
            Set<String> digests = new HashSet<>();
            for (Signature s : signers(env)) digests.add(sha256Hex(s.toByteArray()));
            return matches(digests, pins) ? Finding.NONE : Finding.hit(MISMATCH);
        } catch (Exception e) {
            return Finding.hit(UNREADABLE);
        }
    }

    @SuppressWarnings("deprecation")
    private static Signature[] signers(DetectorEnv env) throws PackageManager.NameNotFoundException {
        PackageManager pm = env.context.getPackageManager();
        String pkg = env.context.getPackageName();
        if (Build.VERSION.SDK_INT >= 28) {
            PackageInfo info = pm.getPackageInfo(pkg, PackageManager.GET_SIGNING_CERTIFICATES);
            return info.signingInfo.getApkContentsSigners();
        }
        return pm.getPackageInfo(pkg, PackageManager.GET_SIGNATURES).signatures;
    }
}
