package io.mobileshield.detectors;

import io.mobileshield.BuildConfig;
import io.mobileshield.internal.NativeBridge;
import io.mobileshield.model.ThreatCategory;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * tampering.nativeVsJava: reads signals once through raw syscalls (native) and once through
 * independent Java APIs. Hiding tools usually patch one side, so disagreement is the evidence.
 */
public final class NativeVsJavaCrossCheck implements Detector {
    static final double CONFIDENCE = 0.95;

    // Keep in sync with kSuPaths in cpp/detectors/RootDetect.cpp.
    static final String[] SU_PATHS = {
        "/data/local/su", "/data/local/bin/su", "/data/local/xbin/su", "/sbin/su", "/su/bin/su",
        "/system/bin/su", "/system/bin/.ext/su", "/system/bin/failsafe/su", "/system/sd/xbin/su",
        "/system/usr/we-need-root/su", "/system/xbin/su", "/cache/su", "/data/su", "/dev/su"
    };

    /** One side's view of the overlapping signals. */
    public static final class Readings {
        public final boolean suPresent;
        public final int tracerPid;      // -1 = unreadable
        public final String version;     // null = unknown
        public final String apkDir;      // "" = unknown

        public Readings(boolean suPresent, int tracerPid, String version, String apkDir) {
            this.suPresent = suPresent;
            this.tracerPid = tracerPid;
            this.version = version;
            this.apkDir = apkDir == null ? "" : apkDir;
        }
    }

    @Override public String id() { return "tampering.nativeVsJava"; }
    @Override public ThreatCategory category() { return ThreatCategory.TAMPERING; }

    /** Names of the signals the two sides disagree on; unknown values never count as disagreement. */
    public static List<String> disagreements(Readings nativeSide, Readings javaSide) {
        List<String> out = new ArrayList<>();
        if (nativeSide.suPresent != javaSide.suPresent) out.add("su");
        if (nativeSide.tracerPid >= 0 && javaSide.tracerPid >= 0 && (nativeSide.tracerPid > 0) != (javaSide.tracerPid > 0)) {
            out.add("tracerPid");
        }
        if (nativeSide.version != null && !nativeSide.version.equals(javaSide.version)) out.add("version");
        if (!nativeSide.apkDir.isEmpty() && !javaSide.apkDir.isEmpty() && !sameDir(nativeSide.apkDir, javaSide.apkDir)) {
            out.add("apkDir");
        }
        return out;
    }

    @Override public Finding run(DetectorEnv env) {
        try {
            String pkg = env.context.getPackageName();
            List<String> diff = disagreements(nativeReadings(pkg), javaReadings(env));
            if (diff.isEmpty()) return Finding.NONE;
            // A debugger attaching between the two reads is the one benign race: read both again.
            if (diff.size() == 1 && diff.get(0).equals("tracerPid")) {
                diff = disagreements(nativeReadings(pkg), javaReadings(env));
            }
            return diff.isEmpty() ? Finding.NONE : Finding.hit(CONFIDENCE, "mismatch", join(diff));
        } catch (Throwable t) {
            return Finding.UNSUPPORTED;
        }
    }

    private static Readings nativeReadings(String pkg) {
        String[] r = NativeBridge.crossReadings(pkg);
        if (r == null || r.length != 4) throw new IllegalStateException("native readings unavailable");
        return new Readings("1".equals(r[0]), parseInt(r[1]), r[2], r[3]);
    }

    private static Readings javaReadings(DetectorEnv env) {
        boolean su = false;
        for (String p : SU_PATHS) {
            if (new File(p).exists()) { su = true; break; }
        }
        String dir = "";
        String source = env.context.getApplicationInfo().sourceDir;
        if (source != null) dir = new File(source).getParent();
        return new Readings(su, javaTracerPid(), BuildConfig.SDK_VERSION, dir);
    }

    static int javaTracerPid() {
        try (BufferedReader reader = new BufferedReader(new FileReader("/proc/self/status"))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (line.startsWith("TracerPid:")) return parseInt(line.substring(10).trim());
            }
        } catch (IOException ignored) {
            // Unreadable counts as unknown, not as disagreement.
        }
        return -1;
    }

    private static boolean sameDir(String a, String b) {
        if (a.equals(b)) return true;
        try {
            return new File(a).getCanonicalPath().equals(new File(b).getCanonicalPath());
        } catch (IOException e) {
            return false;
        }
    }

    private static int parseInt(String s) {
        try { return Integer.parseInt(s.trim()); } catch (NumberFormatException e) { return -1; }
    }

    private static String join(List<String> parts) {
        StringBuilder sb = new StringBuilder();
        for (String p : parts) {
            if (sb.length() > 0) sb.append(',');
            sb.append(p);
        }
        return sb.toString();
    }
}
